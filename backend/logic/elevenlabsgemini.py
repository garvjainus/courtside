import requests
import json
import os
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs
from elevenlabs import play

load_dotenv()

from google import genai
from google.genai import types
# -------------------------------
# Configuration & API Credentials
# -------------------------------

# Gemini API configuration (replace with your actual endpoint and key)
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

client1 = ElevenLabs()


# -------------------------------
# Helper Functions
# -------------------------------

def generate_commentary_prompt(events):
    """
    Construct a compelling prompt for Gemini.
    This prompt instructs the model to generate concise yet intriguing commentary
    for each game event.
    """
    prompt = (
        "You are an expert sports commentator known for vivid, punchy, and concise commentary. "
        "Given the following game events, produce a cohesive and compelling narrative. "
        "Each line should be concise yet enticing, highlighting the drama of the play:\n\n"
    )
    for event in events:
        # Format the timestamp as seconds with two decimals.
        time_str = f"{event['time']:.2f}s"
        etype = event["event_type"]
        details = event["details"]
        if etype == "pass":
            line = (f"At {time_str}, a slick pass is executed from player {details['from']} "
                    f"to player {details['to']}, igniting the momentum.")
        elif etype == "shot":
            line = (f"At {time_str}, player {details['possession']} takes a daring shot "
                    f"that is {details.get('result', 'undecided')}!")
        elif etype == "turnover":
            line = (f"At {time_str}, player {details['lost_by']} loses control, resulting in a turnover.")
        elif etype == "steal":
            line = (f"At {time_str}, an electrifying steal by player {details['gained_by']} shifts the tide!")
        elif etype == "dribble":
            line = (f"At {time_str}, player {details['player']} displays masterful dribbling skills.")
        else:
            line = f"At {time_str}, an event of type '{etype}' occurs."
        prompt += line + "\n"
    prompt += "\nProvide a final cohesive commentary narrative that is engaging and vivid."
    return prompt

def generate_commentary_with_gemini(prompt):
    """
    Send the prompt to the Gemini API to generate sports commentary.
    This function returns the commentary text on success.
    """
    response = client.models.generate_content(
    model="gemini-2.0-flash",
    contents=prompt,
    config=types.GenerateContentConfig(
        max_output_tokens=50,
        temperature=0.8
    )
)
    if response.status_code == 200:
        data = response.json()
        # Assuming the API returns the generated text in the 'text' field.
        commentary = data.get("text", "").strip()
        if commentary:
            return commentary
        else:
            raise Exception("Gemini API returned an empty response.")
    else:
        raise Exception(f"Gemini API error {response.status_code}: {response.text}")

def text_to_speech_elevenlabs(text, output_filename="sports_commentary.mp3"):
    """
    Convert the provided text to an audio file using the ElevenLabs API.
    Saves the audio file to the specified output filename.
    """
    audio = client1.text_to_speech.convert(
        text=text,
        voice_id="J29vD33N1CtxCmqQRPOHJ",
        model_id="eleven_multilingual_v2",
        output_format="mp3_44100_128",
    )
    if audio.status_code == 200:
        # Save the returned audio binary content.
        with open(output_filename, "wb") as f:
            f.write(audio.content)
        print(f"Audio commentary saved as {output_filename}")
    else:
        raise Exception(f"ElevenLabs API error {audio.status_code}: {audio.text}")