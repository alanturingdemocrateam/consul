import os
import json
import time

time.sleep(5)

data = [
    {"id": 0, "name": "Tag ID 0"},
    {"id": 1, "name": "Tag ID 1"},
    {"id": 2, "name": "Tag ID 2"},
    {"id": 3, "name": "Tag ID 3"}
]

with open(os.getcwd() + "/public/machine_learning/data/machine_learning_tags_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)


data = [
    {"tag_id": 0, "taggable_id": 1, "taggable_type": "Proposal"},
    {"tag_id": 1, "taggable_id": 1, "taggable_type": "Proposal"},
    {"tag_id": 2, "taggable_id": 2, "taggable_type": "Proposal"},
    {"tag_id": 3, "taggable_id": 3, "taggable_type": "Proposal"},
    {"tag_id": 0, "taggable_id": 1, "taggable_type": "Debate"},
    {"tag_id": 1, "taggable_id": 1, "taggable_type": "Debate"},
    {"tag_id": 2, "taggable_id": 2, "taggable_type": "Debate"},
    {"tag_id": 3, "taggable_id": 3, "taggable_type": "Debate"},
    {"tag_id": 0, "taggable_id": 1, "taggable_type": "Budget::Investment"},
    {"tag_id": 1, "taggable_id": 1, "taggable_type": "Budget::Investment"},
    {"tag_id": 2, "taggable_id": 2, "taggable_type": "Budget::Investment"},
    {"tag_id": 3, "taggable_id": 3, "taggable_type": "Budget::Investment"}
]

with open(os.getcwd() + "/public/machine_learning/data/machine_learning_taggings_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)

time.sleep(5)
