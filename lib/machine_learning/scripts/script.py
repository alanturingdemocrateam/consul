import os
import csv
import time

time.sleep(5)

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_proposals_related_nmf.csv", mode="w") as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=";", quotechar='"', quoting=csv.QUOTE_MINIMAL)

    csv_writer.writerow([1, 3, 5, 7, 9])
    csv_writer.writerow([2, 4, 7, None, 8, 10])
    csv_writer.writerow([3, 10, 4, "", 12, 14])
    csv_writer.writerow([4, 1, 2, 3])

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_comments_textrank.csv", mode="w") as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=";", quotechar='"', quoting=csv.QUOTE_MINIMAL)

    csv_writer.writerow(["id", "commentable_id", "commentable_type", "body"])
    csv_writer.writerow([0, 1, "Proposal", "Resumen de comentarios de la propuesta con ID 1"])
    csv_writer.writerow([1, 2, "Proposal", "Resumen de comentarios de la propuesta con ID 2"])
    csv_writer.writerow([2, 3, "Proposal", "Resumen de comentarios de la propuesta con ID 3"])
    csv_writer.writerow([3, 4, "Proposal", "Resumen de comentarios de la propuesta con ID 4"])

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_tags_nmf.csv", mode="w") as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=";", quotechar='"', quoting=csv.QUOTE_MINIMAL)

    csv_writer.writerow(["id", "name", "taggings_count", "kind"])
    csv_writer.writerow([0, "Tag ID 0", 10, None])
    csv_writer.writerow([1, "Tag ID 1", 20, None])
    csv_writer.writerow([2, "Tag ID 2", 30, ""])
    csv_writer.writerow([3, "Tag ID 3", 40, ""])

with open(os.getcwd() + "/lib/machine_learning/scripts/machine_learning_taggings_nmf.csv", mode="w") as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=";", quotechar='"', quoting=csv.QUOTE_MINIMAL)

    csv_writer.writerow(["tag_id", "taggable_id", "taggable_type"])
    csv_writer.writerow([0, 1, "Proposal"])
    csv_writer.writerow([1, 1, "Proposal"])
    csv_writer.writerow([2, 2, "Proposal"])
    csv_writer.writerow([3, 3, "Proposal"])

time.sleep(5)
