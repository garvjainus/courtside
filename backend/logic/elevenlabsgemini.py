import os
import time
import dotenv
from elevenlabs.client import ElevenLabs
from elevenlabs import play
from google import genai
from google.genai import types
from mutagen.mp3 import MP3  # Used to get audio duration

dotenv.load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
client1 = ElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))


def generate_commentary_prompt(event):
    """
    Create a prompt for Gemini for a single event.
    """
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
    
    prompt = (
        "You are an expert sports commentator known for vivid and punchy commentary. "
        "Provide a concise and exciting commentary for the following event:\n\n" +
        line + "\n"
    )
    return prompt

def generate_commentary_for_event(event):
    """
    Generate commentary for a single event using the Gemini API.
    """
    prompt = generate_commentary_prompt(event)
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
        commentary = data.get("text", "").strip()
        if commentary:
            return commentary
        else:
            raise Exception(f"Gemini API returned an empty response for event at {event['time']:.2f}s")
    else:
        raise Exception(f"Gemini API error {response.status_code}: {response.text}")

def text_to_speech_elevenlabs(text, output_filename):
    """
    Convert the provided text to an audio file using the ElevenLabs API.
    """
    audio = client1.text_to_speech.convert(
        text=text,
        voice_id="J29vD33N1CtxCmqQRPOHJ",
        model_id="eleven_multilingual_v2",
        output_format="mp3_44100_128",
    )
    if audio.status_code == 200:
        with open(output_filename, "wb") as f:
            f.write(audio.content)
        print(f"Audio commentary saved as {output_filename}")
    else:
        raise Exception(f"ElevenLabs API error {audio.status_code}: {audio.text}")

def generate_and_prepare_commentary(events):
    """
    For each event, generate commentary and corresponding TTS audio.
    Returns a list of dictionaries with 'time', 'commentary', and 'audio_file'.
    """
    segments = []
    for i, event in enumerate(events):
        commentary = generate_commentary_for_event(event)
        audio_filename = f"commentary_{i}.mp3"
        text_to_speech_elevenlabs(commentary, output_filename=audio_filename)
        segments.append({
            "time": event["time"],
            "commentary": commentary,
            "audio_file": audio_filename
        })
    return segments

def schedule_commentary_playback(segments, video_start_time):
    """
    Schedule playback so each commentary plays at its corresponding video timestamp.
    Ensures that each audio finishes playing before the next one starts.
    """
    for segment in segments:
        # Calculate delay until the commentary should start
        delay = segment["time"] - (time.time() - video_start_time)
        if delay > 0:
            time.sleep(delay)
        
        # Play the commentary audio
        play(segment["audio_file"])
        print(f"Played commentary for event at {segment['time']:.2f}s")
        
        # Wait until the audio file has finished playing to avoid overlap
        audio = MP3(segment["audio_file"])
        duration = audio.info.length
        time.sleep(duration)

if __name__ == "__main__":
    
    events = [
        {
            "time": 5.25,
            "event_type": "pass",
            "details": {"from": "A", "to": "B"}
        },
        {
            "time": 12.50,
            "event_type": "shot",
            "details": {"possession": "B", "result": "scored"}
        },
        {
            "time": 20.75,
            "event_type": "steal",
            "details": {"gained_by": "C"}
        }
    ]
    
    # Generate commentary segments and prepare their audio files
    segments = generate_and_prepare_commentary(events)
    
    # Mark the video start time (assumes video playback starts now)
    video_start_time = time.time()
    
    # Schedule the commentary playback to sync with the video
    schedule_commentary_playback(segments, video_start_time)