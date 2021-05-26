import os
import json
import time

time.sleep(5)

data = [
    {"commentable_id": 1, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 1"},
    {"commentable_id": 2, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 2"},
    {"commentable_id": 3, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 3"},
    {"commentable_id": 4, "commentable_type": "Proposal", "body": "Resumen de comentarios de la propuesta con ID 4"},
    {"commentable_id": 1, "commentable_type": "Debate", "body": "Resumen de comentarios del debate con ID 1"},
    {"commentable_id": 2, "commentable_type": "Debate", "body": "Resumen de comentarios del debate con ID 2"},
    {"commentable_id": 3, "commentable_type": "Debate", "body": "Resumen de comentarios del debate con ID 3"},
    {"commentable_id": 4, "commentable_type": "Debate", "body": "Resumen de comentarios del debate con ID 4"},
    {"commentable_id": 1, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 1"},
    {"commentable_id": 2, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 2"},
    {"commentable_id": 3, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 3"},
    {"commentable_id": 4, "commentable_type": "Budget::Investment", "body": "Resumen de comentarios del proyecto con ID 4"}
]

with open(os.getcwd() + "/public/machine_learning/data/machine_learning_comments_textrank.json", mode="w") as json_file:
    json.dump(data, json_file)

time.sleep(5)
