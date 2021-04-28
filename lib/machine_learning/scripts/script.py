import os
import json
import time

time.sleep(5)


data = [
    [1, 3, 5, 7, 9],
    [2, 4, 7, None, 8, 10],
    [3, 10, 4, "", 12, 14],
    [4, 1, 2, 3]
]

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_proposals_related_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_budget_investments_related_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)

data = [
    {"commentable_id": 1, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 1"},
    {"commentable_id": 2, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 1"},
    {"commentable_id": 3, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 1"},
    {"commentable_id": 4, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 1"},
    {"commentable_id": 1, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 1"},
    {"commentable_id": 2, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 1"},
    {"commentable_id": 3, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 1"},
    {"commentable_id": 4, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 1"}
]

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_comments_textrank.json", mode="w") as json_file:
    json.dump(data, json_file)


data = [
    {"id": 0, "name": "Tag ID 0"},
    {"id": 1, "name": "Tag ID 1"},
    {"id": 2, "name": "Tag ID 2"},
    {"id": 3, "name": "Tag ID 3"}
]

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_tags_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)


data = [
    {"tag_id": 0, "taggable_id": 1, "taggable_type": "Proposal"},
    {"tag_id": 1, "taggable_id": 1, "taggable_type": "Proposal"},
    {"tag_id": 2, "taggable_id": 2, "taggable_type": "Proposal"},
    {"tag_id": 3, "taggable_id": 3, "taggable_type": "Proposal"},
    {"tag_id": 0, "taggable_id": 1, "taggable_type": "Budget::Investment"},
    {"tag_id": 1, "taggable_id": 1, "taggable_type": "Budget::Investment"},
    {"tag_id": 2, "taggable_id": 2, "taggable_type": "Budget::Investment"},
    {"tag_id": 3, "taggable_id": 3, "taggable_type": "Budget::Investment"}
]

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_taggings_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)



time.sleep(5)
