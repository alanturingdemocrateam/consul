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

with open(os.getcwd() + "/public/machine_learning/data/machine_learning_proposals_related_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)

with open(os.getcwd() + "/public/machine_learning/data/machine_learning_budget_investments_related_nmf.json", mode="w") as json_file:
    json.dump(data, json_file)

time.sleep(5)
