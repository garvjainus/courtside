from moviepy.editor import VideoFileClip, AudioFileClip

def overlay_audio_on_video(video_path, audio_path, output_path):
    video_clip = VideoFileClip(video_path)
    
    audio_clip = AudioFileClip(audio_path)
    
    audio_clip = audio_clip.set_duration(video_clip.duration)
    
    final_clip = video_clip.set_audio(audio_clip)
    
    final_clip.write_videofile(output_path, codec="libx264", audio_codec="aac")