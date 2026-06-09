from transformers import AutoModelForCausalLM, AutoTokenizer
#from transformers import AutoModelForCausalLM, LlamaTokenizer

# Cargar el tokenizador y el modelo Open LLaMA desde Hugging Face
model_name = "openlm-research/open_llama_3b"

tokenizer = AutoTokenizer.from_pretrained(model_name)
#model = AutoModelForCausalLM.from_pretrained(model_name)
#tokenizer = LlamaTokenizer.from_pretrained(model_name, use_fast=False)
model = AutoModelForCausalLM.from_pretrained(model_name)

# Generar texto
input_text = "Hola, ¿cómo estás?"
inputs = tokenizer(input_text, return_tensors="pt")
output = model.generate(**inputs, max_new_tokens=50)

print(tokenizer.decode(output[0], skip_special_tokens=True))
