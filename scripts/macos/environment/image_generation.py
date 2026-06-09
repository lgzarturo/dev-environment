from diffusers import StableDiffusionPipeline
import torch

# Cargar el modelo de Stable Diffusion desde Hugging Face
model_id = "runwayml/stable-diffusion-v1-5"
pipe = StableDiffusionPipeline.from_pretrained(model_id, torch_dtype=torch.float16)
pipe = pipe.to("mps")  # "mps" para usar Apple Silicon

# Generar una imagen
prompt = "A futuristic cityscape at sunset"
image = pipe(prompt).images[0]

# Guardar la imagen
image.save("output_image.png")
