"""
Comments summaries

This script generates for each proposal a summary of all its comments.
Running time: Max 1 hour for 10.000 proposals.
Technique used: GloVe embeddings and TextRank.
"""

#!/usr/bin/env python
# coding: utf-8

# In[1]:


# In[2]:


# DOWNLOAD THE GLOVE EMBEDDINGS:
#!wget http://dcc.uchile.cl/~jperez/word-embeddings/glove-sbwc.i25.vec.gz
#!gunzip glove-sbwc*.gz 

# In[3]:


config_file = '../data/comments_textrank.ini'
logging_file = '../data/comments_textrank.log'

# Read the configuration file
import configparser
config = configparser.ConfigParser()
config.read(config_file)

sent_token_lang = config['PREPROCESSING']['sent_token_lang']
stopwords_lang = config['PREPROCESSING']['stopwords_lang']
nltk_download = config['PREPROCESSING'].getboolean('nltk_download')

glove_file = '../data/' + config['SUMMARISATION']['glove_file']
threshold_factor = config['SUMMARISATION'].getfloat('threshold_factor')
max_size_of_summaries = config['SUMMARISATION'].getint('max_size_of_summaries')

logging_level = config['LOGGING']['logging_level']


# In[4]:


# Input file:
inputjsonfile = '../data/comments.json'
col_id = 'commentable_id'
col_content = 'body'

# Output files:
comments_summaries_filename_nofa = '../data/ml_comments_summaries_b.json'
comments_summaries_filename = '../data/ml_comments_summaries.json'

tqdm_notebook = True


# In[5]:


import logging

logging.basicConfig(filename=logging_file, 
                    filemode='w', 
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    level=logging_level)
#logging.info('message')


# In[6]:


import os
import pandas as pd
import numpy as np
import re
from unicodedata import normalize


# In[7]:


import nltk
if nltk_download:
    nltk.download('stopwords')
    nltk.download('punkt')


# In[8]:


from nltk.corpus import stopwords
from nltk.stem import PorterStemmer
from nltk.tokenize import word_tokenize, sent_tokenize


# In[9]:


from sklearn.metrics.pairwise import cosine_similarity
import networkx as nx
import collections


# In[10]:


import tqdm
from tqdm.notebook import tqdm_notebook
tqdm_notebook.pandas()
# to use tqdm in pandas use progress_apply instead of apply


# In[11]:


# Extract word vectors
word_embeddings = {}
f = open(glove_file, encoding='utf-8')
for line in f:
    values = line.split()
    word = values[0]
    coefs = np.asarray(values[1:], dtype='float32')
    word_embeddings[word] = coefs
f.close()


# In[ ]:





# # Read the comments and join the comments belonging to the same proposal

# In[12]:


comments_input_df = pd.read_json(inputjsonfile,orient="records")
comments_input_df = comments_input_df[comments_input_df['commentable_type'] == 'Proposal']

comments_input_df = comments_input_df[[col_id]+[col_content]]

# Normalise characters
comments_input_df[col_content] = comments_input_df[col_content].apply(lambda x: normalize('NFKC',x))
    
comments_input_df = comments_input_df.sort_values(by=col_id)
comments_input_df.reset_index(drop=True,inplace=True)


# In[13]:


# Drop empty texts

empty_txt_ids = []
for idx,row in comments_input_df.iterrows():
    if row['body'].strip() == '':
        empty_txt_ids.append(idx)
        
comments_input_df = comments_input_df.drop(empty_txt_ids)
comments_input_df.reset_index(drop=True,inplace=True)


# In[14]:


comments_df = pd.DataFrame()

temp_comments_joined = []
temp_comments_number = []
temp_proposal_id = []
for prop_id in sorted(list(set(comments_input_df[col_id].tolist()))):
    temp_list = comments_input_df[comments_input_df[col_id] == prop_id][col_content].tolist()
    temp_comments_joined.append('\n'.join(temp_list))
    temp_comments_number.append(len(temp_list))
    temp_proposal_id.append(prop_id)
    
comments_df['prop_id'] = temp_proposal_id
comments_df['comments_joined'] = temp_comments_joined
comments_df['comments_number'] = temp_comments_number


# In[15]:


# # Stats
# print(len(comments_df))
# print(len(comments_df[(comments_df['comments_number'] >= 0) & (comments_df['comments_number'] < 10)]))
# print(len(comments_df[(comments_df['comments_number'] >= 10) & (comments_df['comments_number'] < 50)]))
# print(len(comments_df[(comments_df['comments_number'] >= 50) & (comments_df['comments_number'] < 900)]))


# In[ ]:





# # Make comments lowercase

# In[16]:


comments_df['comments_joined'] = comments_df['comments_joined'].apply(lambda x: x.lower())


# In[ ]:





# # Split sentences

# In[17]:


def split_sentences(txt):
    new_text_1 = sent_tokenize(txt,sent_token_lang)
    #outputs [] if txt is ''; or made of ' ' or '\n'
    
    new_text_2 = []    
    if new_text_1 != []:
        for tok1 in new_text_1:
            new_text_2 += tok1.split('\n')
            #outputs [''] if txt is ''
        new_text_2 = [tok.strip() for tok in new_text_2 if tok.strip() != '']
    
    if new_text_2 == []:
        new_text_2 = ['']
        
    return new_text_2


# In[18]:


comments_df['comments_sentences'] = comments_df['comments_joined'].apply(split_sentences)


# In[ ]:





# # Calculate sentence embeddings

# In[19]:


# List of stop words to be removed
stop_words = set(stopwords.words(stopwords_lang))
for word in stop_words:
    stop_words = stop_words.union({re.sub(r"á","a",word)})
    stop_words = stop_words.union({re.sub(r"é","e",word)})
    stop_words = stop_words.union({re.sub(r"í","i",word)})
    stop_words = stop_words.union({re.sub(r"ó","o",word)})
    stop_words = stop_words.union({re.sub(r"ú","u",word)})
    
# additional terms removed when found as an independent character
additional_stop_words = {'(',')',',','.','...','?','¿','!','¡',':',';','d','q','u'}
all_stop_words = stop_words.union(additional_stop_words)


# In[20]:


def sentences_embeddings(sents):
    sent_embs = []
    
    for sent in sents:           
        words = set(word_tokenize(sent))
        words = words-all_stop_words
        if len(words) != 0:
            emb = sum([word_embeddings.get(word, np.zeros(300)) for word in words])/(
                len(words)+0.001)
        else:
            emb = np.zeros(300)
        sent_embs.append(emb)

    return sent_embs


# In[21]:


if tqdm_notebook:
    comments_df['comments_sentences_embeddings'] = comments_df[
        'comments_sentences'].progress_apply(sentences_embeddings)
else:
    comments_df['comments_sentences_embeddings'] = comments_df[
        'comments_sentences'].apply(sentences_embeddings)


# In[ ]:





# # Calculate sentence scores

# In[22]:


def sentences_scores(sents, sent_embs): 
    
    # similarity matrix
    if len(sent_embs) > 1:
        stacked_sent_embs = np.stack(sent_embs)
        sim_mat = cosine_similarity(stacked_sent_embs,stacked_sent_embs)
        np.fill_diagonal(sim_mat, 0)
    elif len(sent_embs) == 1:
        sim_mat = np.array([[0.]])
    else:
        return collections.OrderedDict([('',1.0)])

    nx_graph = nx.from_numpy_array(sim_mat)
    
    try:
        sentence_weight_temp = nx.pagerank(nx_graph)
    except:
        sentence_weight_temp = dict.fromkeys([x for x in range(len(sents))], 0)
    
    sentence_weights = {sents[key]: value for key, value in sentence_weight_temp.items()}
    
    sorted_sentence_weights = sorted(sentence_weights.items(), key=lambda elem: elem[1], reverse=True)
    sentence_scores = collections.OrderedDict(sorted_sentence_weights)
    
    return sentence_scores


# In[23]:


def plot_sentences_network(sents, sent_embs):
    import matplotlib.pyplot as plt

    # similarity matrix
    if len(sent_embs) > 1:
        stacked_sent_embs = np.stack(sent_embs)
        sim_mat = cosine_similarity(stacked_sent_embs,stacked_sent_embs)
        np.fill_diagonal(sim_mat, 0)
    elif len(sent_embs) == 1:
        sim_mat = np.array([[0.]])
    else:
        print('Nothing to plot')
        return
   
    nx_graph = nx.from_numpy_array(sim_mat)
    
    plt.plot()
    nx.draw(nx_graph, with_labels=True)


# In[24]:


comments_df['comments_sentences_scores'] = comments_df[['comments_sentences','comments_sentences_embeddings']].progress_apply(
    lambda row: sentences_scores(row['comments_sentences'],row['comments_sentences_embeddings']),axis=1)


# In[ ]:





# # Generate the summaries

# In[25]:


def comments_summary(sentence_weight, threshold_factor, *totalwords):
    
    threshold = threshold_factor * np.mean(list(sentence_weight.values()))
    
    sentence_counter = 0
    comments_summary = ''
              
    summary_num_words = 0   
        
    for sentence in sentence_weight:
        if sentence_weight[sentence] >= (threshold):
            if len(totalwords) == 0:
                comments_summary += "\n- " + sentence
                sentence_counter += 1
            elif summary_num_words < totalwords[0]:
                comments_summary += "\n- " + sentence
                sentence_counter += 1
                summary_num_words += len(sentence.split())
       
    comments_summary = comments_summary.lstrip()
    return comments_summary


# In[26]:


comments_df['comments_summary'] = comments_df['comments_sentences_scores'].apply(
    lambda x: comments_summary(x,threshold_factor,max_size_of_summaries))


# In[27]:


# comments_df


# In[28]:


# for idx,row in comments_input_df[comments_input_df['commentable_id'] == 10].iterrows():
#     print(row['body'])
#     print('-------')


# In[29]:


#print(comments_df.loc[8,'comments_summary'])


# In[ ]:





# In[30]:


comments_df['commentable_type'] = ['Proposal']*len(comments_df)
comments_summaries_df = comments_df[['prop_id','commentable_type','comments_summary']]
comments_summaries_df.reset_index(level=0, inplace=True)


# In[31]:


comments_summaries_df = comments_summaries_df.rename(
    columns={"index": "id", "prop_id": "commentable_id", "comments_summary": "body"})


# In[32]:


#comments_summaries_df


# In[33]:


#comments_summaries_df.to_json(comments_summaries_filename_nofa,orient="records")


# In[34]:


comments_summaries_df.to_json(comments_summaries_filename,orient="records", force_ascii=False)


# In[ ]:





# In[ ]:


logging.info('Script executed correctly.')


# In[ ]:




