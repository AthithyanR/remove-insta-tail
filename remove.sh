#! /bin/bash

set -e  # Exit on error

# Configuration
file_suffix=".mp4"
trim_seconds=4  # Number of seconds to trim from the end

# Check if required commands exist
command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg is required but not installed."; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "Error: ffprobe is required but not installed."; exit 1; }

# Get folder path from argument or use current directory
if [ $# -eq 1 ]; then
    folder_path="$1"
else
    folder_path="$(pwd)"
    echo "No path provided. Using current directory: $folder_path"
    read -p "Continue with this directory? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
fi

# Check if folder exists
if [ ! -d "$folder_path" ]; then
    echo "Error: Directory $folder_path does not exist"
    exit 1
fi

# Get all videos with the suffix in the folder
videos=$(find "$folder_path" -type f -name "*$file_suffix")

if [ -z "$videos" ]; then
    echo "No videos found with suffix $file_suffix in $folder_path"
    exit 0
fi

echo "Found $(echo "$videos" | wc -l) videos to process"
read -p "Continue with processing? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 0
fi

for video in $videos; do
    echo "Processing: $video"
    
    # Get the duration of the video
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")
    
    if [ -z "$duration" ]; then
        echo "Warning: Could not get duration for $video, skipping..."
        continue
    fi
    
    upto_duration=$(echo "$duration - $trim_seconds" | bc)
    
    if (( $(echo "$upto_duration <= 0" | bc -l) )); then
        echo "Warning: Video $video is too short to trim, skipping..."
        continue
    fi
    
    echo "Trimming to $upto_duration seconds"
    
    # Create temporary file with .tmp extension
    temp_file="${video%.mp4}.tmp"
    
    # Trim the video
    if ffmpeg -i "$video" -ss 00:00:00 -t "$upto_duration" -c copy "$temp_file" 2>/dev/null; then
        # Replace original with trimmed version
        mv "$temp_file" "$video"
        echo "Successfully processed: $video"
    else
        echo "Error: Failed to process $video"
        rm -f "$temp_file"  # Clean up temp file if it exists
    fi
done

echo "Processing complete!"