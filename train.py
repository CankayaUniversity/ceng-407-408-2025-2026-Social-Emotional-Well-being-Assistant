from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer
)
from sklearn.metrics import accuracy_score, f1_score
import torch

# --------------------------------------------------
# 1) DATASET YÜKLE
# --------------------------------------------------
dataset = load_dataset("csv", data_files="duygular.csv")

# train / test split
dataset = dataset["train"].train_test_split(test_size=0.1, seed=42)

print(dataset)

# --------------------------------------------------
# 2) LABEL MAPPING (SABİT & GÜVENLİ)
# --------------------------------------------------
labels = sorted(dataset["train"].unique("emotion"))

label2id = {label: i for i, label in enumerate(labels)}
id2label = {i: label for label, i in label2id.items()}

print("Label mapping:", label2id)

# --------------------------------------------------
# 3) TOKENIZER + MODEL
# --------------------------------------------------
model_name = "dbmdz/bert-base-turkish-cased"

tokenizer = AutoTokenizer.from_pretrained(model_name)

model = AutoModelForSequenceClassification.from_pretrained(
    model_name,
    num_labels=len(label2id),
    label2id=label2id,
    id2label=id2label
)

# --------------------------------------------------
# 4) TOKENIZATION (DYNAMIC PADDING)
# --------------------------------------------------
def tokenize(batch):
    return tokenizer(
        batch["text"],
        truncation=True
    )

dataset = dataset.map(tokenize, batched=True)

# --------------------------------------------------
# 5) LABEL ENCODE + TEMİZLİK
# --------------------------------------------------
dataset = dataset.rename_column("emotion", "labels")

def encode_labels(example):
    example["labels"] = label2id[example["labels"]]
    return example

dataset = dataset.map(encode_labels)

# gereksiz kolon varsa sil
if "Unnamed: 0" in dataset["train"].column_names:
    dataset = dataset.remove_columns("Unnamed: 0")

dataset = dataset.remove_columns(["text"])

# torch format
dataset.set_format(
    "torch",
    columns=["input_ids", "attention_mask", "labels"]
)

# --------------------------------------------------
# 6) TRAINING ARGUMENTS
# --------------------------------------------------
training_args = TrainingArguments(
    output_dir="./emotion_tr_bert",
    evaluation_strategy="epoch",
    save_strategy="epoch",
    learning_rate=2e-5,
    per_device_train_batch_size=8,
    per_device_eval_batch_size=8,
    num_train_epochs=2,
    weight_decay=0.01,
    logging_steps=50,
    load_best_model_at_end=True,
    metric_for_best_model="eval_f1",
    greater_is_better=True,
    report_to="none"
)

# --------------------------------------------------
# 7) METRICS
# --------------------------------------------------
def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = logits.argmax(axis=1)

    return {
        "accuracy": accuracy_score(labels, preds),
        "f1": f1_score(labels, preds, average="weighted")
    }

# --------------------------------------------------
# 8) TRAINER
# --------------------------------------------------
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset["train"],
    eval_dataset=dataset["test"],
    tokenizer=tokenizer,
    compute_metrics=compute_metrics
)

# --------------------------------------------------
# 9) TRAIN
# --------------------------------------------------
trainer.train()

# --------------------------------------------------
# 10) SAVE MODEL
# --------------------------------------------------
trainer.save_model("emotion_tr_bert")
tokenizer.save_pretrained("emotion_tr_bert")



