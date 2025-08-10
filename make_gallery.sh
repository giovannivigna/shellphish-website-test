#!/bin/bash
# set -e  # Temporarily disabled for debugging

# Parse command line arguments
FORCE_REGENERATE=false
USE_TIMESTAMPS=true
EVENTS_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE_REGENERATE=true
      shift
      ;;
    --no-timestamps)
      USE_TIMESTAMPS=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] <events-directory>"
      echo ""
      echo "Options:"
      echo "  -f, --force         Force regeneration of all thumbnails"
      echo "  --no-timestamps     Disable timestamp-based file renaming"
      echo "  -h, --help          Show this help message"
      echo ""
      echo "The events directory should contain subdirectories in format: YYYYMMDD_EVENTNAME"
      exit 0
      ;;
    *)
      if [[ -z "$EVENTS_DIR" ]]; then
        EVENTS_DIR="$1"
      else
        echo "Error: Multiple directories specified"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$EVENTS_DIR" || ! -d "$EVENTS_DIR" ]]; then
  echo "Usage: $0 [OPTIONS] <events-directory>"
  echo ""
  echo "Options:"
  echo "  -f, --force    Force regeneration of all thumbnails"
  echo "  -h, --help     Show this help message"
  echo ""
  echo "The events directory should contain subdirectories in format: YYYYMMDD_EVENTNAME"
  exit 1
fi

# Ensure EVENTS_DIR is absolute path
if [[ ! "$EVENTS_DIR" = /* ]]; then
  EVENTS_DIR="$(pwd)/$EVENTS_DIR"
fi

# Function to check if a directory name matches the event pattern (YYYYMMDD_EVENTNAME)
is_event_directory() {
  local dirname="$1"
  echo "    🔍 Checking pattern for: '$dirname'"
  if [[ "$dirname" =~ ^[0-9]{8}_.+$ ]]; then
    echo "    ✅ Matches event pattern"
    return 0  # true
  else
    echo "    ❌ Does not match event pattern (expected: YYYYMMDD_EVENTNAME)"
    return 1  # false
  fi
}

# Function to extract timestamp from media file
extract_timestamp() {
  local file="$1"
  local extension="${file##*.}"
  
  # Try to extract timestamp using exiftool if available
  if command -v exiftool >/dev/null 2>&1; then
    local timestamp=$(exiftool -DateTimeOriginal -d "%Y%m%d_%H%M%S" "$file" 2>/dev/null | grep "Date/Time Original" | cut -d: -f2- | tr -d ' ')
    if [[ -n "$timestamp" && "$timestamp" != "0000:00:00 00:00:00" ]]; then
      echo "$timestamp"
      return 0
    fi
    
    # Fallback to Create Date
    timestamp=$(exiftool -CreateDate -d "%Y%m%d_%H%M%S" "$file" 2>/dev/null | grep "Create Date" | cut -d: -f2- | tr -d ' ')
    if [[ -n "$timestamp" && "$timestamp" != "0000:00:00 00:00:00" ]]; then
      echo "$timestamp"
      return 0
    fi
  fi
  
  # Fallback to file modification time
  local mod_time=$(stat -f "%Sm" -t "%Y%m%d_%H%M%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1,2 | tr -d ' -:')
  if [[ -n "$mod_time" ]]; then
    echo "$mod_time"
    return 0
  fi
  
  # If all else fails, return empty
  echo ""
  return 1
}

# Function to rename files in an event directory to the required format
rename_files_in_event() {
  local event_dir="$1"
  local event_name=$(basename "$event_dir")
  local renamed_count=0
  
  echo "  🚀 rename_files_in_event() called for: $event_name"
  echo "  📂 Event directory: $event_dir"
  
  # Find all image and video files in the event directory
  echo "  🔍 Searching for media files in: $event_dir"
  local find_result=$(find "$event_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.m4v' \) 2>&1)
  
  if [[ $? -ne 0 ]]; then
    echo "  ❌ Error in find command: $find_result"
    return 1
  fi
  
  if [[ -z "$find_result" ]]; then
    echo "  ℹ️  No media files found in directory"
    return 0
  fi
  
  echo "  📁 Found media files:"
  while IFS= read -r img; do
    echo "    - $(basename "$img")"
  done <<< "$find_result"
  
  if [[ "$USE_TIMESTAMPS" == true ]]; then
    echo "  📅 Using timestamp-based file renaming..."
    
    # Create a temporary file to store timestamp-based sorting
    local temp_file=$(mktemp)
    local counter=1
    
    # Process each file and extract timestamp for sorting
    while IFS= read -r img; do
      filename=$(basename "$img")
      dirname=$(dirname "$img")
      extension="${filename##*.}"
      
      # Extract timestamp from the file
      local timestamp=$(extract_timestamp "$img")
      if [[ -n "$timestamp" ]]; then
        echo "$timestamp|$img|$filename|$dirname|$extension" >> "$temp_file"
        echo "  📅 Extracted timestamp for $filename: $timestamp"
      else
        # If no timestamp found, use a default one based on counter
        local default_timestamp="$(date +%Y%m%d)_$(printf "%06d" $counter)"
        echo "$default_timestamp|$img|$filename|$dirname|$extension" >> "$temp_file"
        echo "  ⚠️  No timestamp found for $filename, using default: $default_timestamp"
        ((counter++))
      fi
    done <<< "$find_result"
    
    # Sort by timestamp and rename files
    if [[ -s "$temp_file" ]]; then
      echo "  🔄 Sorting files by timestamp and renaming..."
      local rename_counter=1
      
      while IFS='|' read -r timestamp img filename dirname extension; do
        # Only rename if the file doesn't already match the pattern
        if [[ ! "$filename" =~ ^${event_name}_[0-9]{4}\. ]]; then
          new_name="${event_name}_$(printf "%04d" $rename_counter).${extension,,}"  # Convert extension to lowercase
          echo "  📝 Renaming: $filename -> $new_name (timestamp: $timestamp)"
          mv "$img" "$dirname/$new_name"
          ((renamed_count++))
        else
          echo "  ⏭️  Skipping $filename (already properly named)"
        fi
        ((rename_counter++))
      done < <(sort "$temp_file" | cut -d'|' -f2-)
    fi
    
    # Clean up temporary file
    rm -f "$temp_file"
  else
    echo "  📝 Using simple sequential file renaming..."
    local counter=1
    
    while IFS= read -r img; do
      filename=$(basename "$img")
      dirname=$(dirname "$img")
      extension="${filename##*.}"
      new_name="${event_name}_$(printf "%04d" $counter).${extension,,}"  # Convert extension to lowercase
      
      # Only rename if the file doesn't already match the pattern
      if [[ ! "$filename" =~ ^${event_name}_[0-9]{4}\. ]]; then
        echo "  📝 Renaming: $filename -> $new_name"
        mv "$img" "$dirname/$new_name"
        ((renamed_count++))
      else
        echo "  ⏭️  Skipping $filename (already properly named)"
      fi
      ((counter++))
    done <<< "$find_result"
  fi
  
  if [[ $renamed_count -eq 0 ]]; then
    echo "  ✅ All files already properly named"
  else
    echo "  ✅ Renamed $renamed_count files"
  fi
  
  # Return the count for global tracking
  return $renamed_count
}

# Function to create gallery for an event
create_event_gallery() {
  local event_dir="$1"
  local event_name=$(basename "$event_dir")
  local thumb_dir="$event_dir/thumbs"
  local html_file="$event_dir/index.html"
  
  # Use global counters for this event
  local event_processed_count=0
  local event_skipped_count=0
  local event_error_count=0
  
  echo "  🚀 create_event_gallery() called for: $event_name"
  echo "  📂 Event directory: $event_dir"
  echo "  📁 Thumb directory: $thumb_dir"
  echo "  📄 HTML file: $html_file"
  
  # Handle thumbs directory based on force regeneration
  if [[ "$FORCE_REGENERATE" == true ]]; then
    echo "  🗑️  Force regeneration: removing existing thumbs directory"
    if [[ -d "$thumb_dir" ]]; then
      rm -rf "$thumb_dir"
      echo "  ✅ Removed existing thumbs directory"
    fi
  fi
  
  # Create thumbs directory
  if [[ "$FORCE_REGENERATE" == true ]]; then
    echo "  🆕 Creating fresh thumbs directory"
  fi
  mkdir -p "$thumb_dir"
  
  # Generate thumbnails
  echo "  Generating thumbnails..."
  local file_count=0
  
  # Get list of files first
  local file_list=$(find "$event_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.m4v' \) 2>/dev/null)
  
  echo "  🔍 Raw file list: '$file_list'"
  
  # Debug: Count files found
  while IFS= read -r img; do
    ((file_count++))
    echo "    🔍 Found file $file_count: $(basename "$img")"
  done <<< "$file_list"
  
  echo "    📁 Found $file_count media files"
  
  while IFS= read -r img; do
    fname=$(basename "$img")
    extension="${fname##*.}"
    thumb_path="$thumb_dir/$fname"
    
    # Check if thumbnail already exists and is newer than source file
    local check_thumb_path="$thumb_path"
    if [[ "${extension,,}" =~ ^(mp4|avi|mov|mkv|wmv|flv|webm|m4v)$ ]]; then
      check_thumb_path="$thumb_dir/${fname%.*}.jpg"  # Check for JPG thumbnail for videos
    else
      check_thumb_path="$thumb_dir/${fname%.*}.jpg"  # Always use .jpg for all thumbnails
    fi
    
    if [[ "$FORCE_REGENERATE" == true ]]; then
      echo "    🔄 Force regenerating thumbnail for $fname"
    elif [[ -f "$check_thumb_path" ]]; then
      if [[ "$check_thumb_path" -nt "$img" ]]; then
        echo "    ⏭️  Skipping $fname (thumbnail already exists and is up-to-date)"
        ((event_skipped_count++))
        continue
      else
        echo "    🔄 Updating thumbnail for $fname (source file is newer)"
      fi
    else
      echo "    ➕ Creating thumbnail for $fname (thumbnail doesn't exist)"
    fi
    
    # Generate thumbnail - always save as JPG
    local thumb_name="${fname%.*}.jpg"  # Remove original extension and add .jpg
    local thumb_path_jpg="$thumb_dir/$thumb_name"
    
    # Check if it's a video file
    if [[ "${extension,,}" =~ ^(mp4|avi|mov|mkv|wmv|flv|webm|m4v)$ ]]; then
      # Generate video thumbnail using ffmpeg - save as JPG
      echo "    Creating video thumbnail for: $fname -> $thumb_name"
      if ffmpeg -i "$img" -ss 00:00:01 -vframes 1 -vf "scale=300:200:force_original_aspect_ratio=decrease,pad=300:200:(ow-iw)/2:(oh-ih)/2:black" "$thumb_path_jpg" 2>/dev/null; then
        echo "    ✅ Video thumbnail created for: $fname"
        ((event_processed_count++))
      else
        echo "    ❌ Error: Could not create video thumbnail for $fname"
        ((event_error_count++))
      fi
    else
      # Generate image thumbnail using ImageMagick - save as JPG
      echo "    Creating image thumbnail for: $fname -> $thumb_name"
      if convert "$img" -resize x200 -gravity center -background black -extent 300x200 "$thumb_path_jpg" 2>/dev/null; then
        echo "    ✅ Image thumbnail created for: $fname"
        ((event_processed_count++))
      else
        echo "    ❌ Error: Could not create thumbnail for $fname"
        ((event_error_count++))
      fi
    fi
  done <<< "$file_list"
  
  echo "  📊 Thumbnail summary: $event_processed_count created, $event_skipped_count skipped, $event_error_count errors"
  
  # Update global counters directly
  ((total_thumbnails_created += event_processed_count))
  ((total_thumbnails_skipped += event_skipped_count))
  ((total_errors += event_error_count))
  
  echo "  🔍 Updated global counters - created: +$event_processed_count, skipped: +$event_skipped_count, errors: +$event_error_count"
  
  # Check if HTML needs to be regenerated
  local html_needs_update=false
  
  # Check if HTML file exists or if thumbs directory is missing/empty
  if [[ "$FORCE_REGENERATE" == true ]] || [[ ! -f "$html_file" ]] || [[ ! -d "$thumb_dir" ]] || [[ -z "$(ls -A "$thumb_dir" 2>/dev/null)" ]]; then
    html_needs_update=true
    if [[ "$FORCE_REGENERATE" == true ]]; then
      echo "  Creating HTML gallery (force regeneration enabled)..."
    elif [[ ! -f "$html_file" ]]; then
      echo "  Creating HTML gallery (file doesn't exist)..."
    elif [[ ! -d "$thumb_dir" ]]; then
      echo "  Creating HTML gallery (thumbs directory missing)..."
    else
      echo "  Creating HTML gallery (thumbs directory empty)..."
    fi
  else
    # Check if any source files are newer than the HTML file
    local newest_file=""
    if [[ -d "$event_dir" ]]; then
      newest_file=$(find "$event_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.m4v' \) -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    fi
    
    if [[ -n "$newest_file" && "$newest_file" -nt "$html_file" ]]; then
      html_needs_update=true
      echo "  Creating HTML gallery (source files are newer)..."
    else
      echo "  ⏭️  HTML gallery is up-to-date, skipping..."
    fi
  fi
  
  if [[ "$html_needs_update" == true ]]; then
    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Photo Gallery - $event_name</title>
  <style>
    body { 
      background:#111; 
      color:#eee; 
      font-family:sans-serif; 
      text-align:center; 
      margin: 0;
      padding: 20px;
    }
    h1 { 
      color: #69f; 
      margin-bottom: 30px;
    }
    .gallery { 
      display: flex; 
      flex-wrap: wrap; 
      justify-content: center; 
      gap: 10px; 
    }
    .gallery a { 
      display: block; 
      text-decoration: none; 
    }
    .gallery img { 
      border: 2px solid #333; 
      transition: border-color 0.3s ease;
      border-radius: 5px;
    }
    .gallery a:hover img { 
      border-color: #69f; 
      transform: scale(1.05);
    }
    .video-indicator {
      position: absolute;
      top: 10px;
      right: 10px;
      background: rgba(0,0,0,0.8);
      color: white;
      padding: 5px 8px;
      border-radius: 3px;
      font-size: 12px;
      font-weight: bold;
      pointer-events: none;
    }
    .back-link {
      margin-top: 30px;
    }
    .back-link a {
      color: #69f;
      text-decoration: none;
      padding: 10px 20px;
      border: 1px solid #69f;
      border-radius: 5px;
      transition: background-color 0.3s ease;
    }
    .back-link a:hover {
      background-color: #69f;
      color: #111;
    }
  </style>
</head>
<body>
<h1>Photo Gallery - $event_name</h1>
<div class="gallery">
EOF

  # Add images and videos to gallery
  # First, find all image thumbnails (JPG, PNG, etc.)
  while IFS= read -r thumb; do
    thumb_name="$(basename "$thumb")"
    rel_thumb="thumbs/$thumb_name"
    
    # Check if this thumbnail corresponds to a video file
    # Remove .jpg extension and check if original video exists
    base_name="${thumb_name%.jpg}"
    base_name="${base_name%.jpeg}"
    base_name="${base_name%.png}"
    
    # Look for corresponding video file in the event directory
    video_found=false
    for video_ext in mp4 avi mov mkv wmv flv webm m4v; do
      if [[ -f "$event_dir/$base_name.$video_ext" ]]; then
        # This is a video thumbnail
        echo "    <a href=\"$base_name.$video_ext\" target=\"_blank\"><div style=\"position:relative;display:inline-block;\"><img src=\"$rel_thumb\" height=\"200\" alt=\"$base_name.$video_ext\"><div class=\"video-indicator\">▶ VIDEO</div></div></a>" >> "$html_file"
        video_found=true
        break
      fi
    done
    
    # If no video found, this is an image thumbnail
    if [[ "$video_found" == false ]]; then
      # Look for corresponding image file
      for img_ext in jpg jpeg png gif bmp; do
        if [[ -f "$event_dir/$base_name.$img_ext" ]]; then
          echo "    <a href=\"$base_name.$img_ext\" target=\"_blank\"><img src=\"$rel_thumb\" height=\"200\" alt=\"$base_name.$img_ext\"></a>" >> "$html_file"
          break
        fi
      done
    fi
  done < <(find "$thumb_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \) | sort)

  cat >> "$html_file" <<EOF
</div>
<div class="back-link">
  <a href="../index.html">← Back to Events</a>
</div>
</body>
</html>
EOF

    echo "  ✅ Gallery created: $html_file"
  else
    echo "  ✅ Gallery already up-to-date: $html_file"
  fi
}

# Create main events index
create_events_index() {
  local events_index="$EVENTS_DIR/gallery.html"
  
  # Check if main index needs to be regenerated
  local index_needs_update=false
  local newest_event_file=""
  
  # Find the newest event HTML file
  if [[ -d "$EVENTS_DIR" ]]; then
    newest_event_file=$(find "$EVENTS_DIR" -type f -name "index.html" -path "*/index.html" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  fi
  
  if [[ ! -f "$events_index" ]] || [[ -n "$newest_event_file" && "$newest_event_file" -nt "$events_index" ]]; then
    index_needs_update=true
    echo "Creating main events index..."
  else
    echo "⏭️  Main events index is up-to-date, skipping..."
  fi
  
  if [[ "$index_needs_update" == true ]]; then
    cat > "$events_index" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Events Photo Galleries</title>
  <style>
    body { 
      background:#111; 
      color:#eee; 
      font-family:sans-serif; 
      text-align:center; 
      margin: 0;
      padding: 20px;
    }
    h1 { 
      color: #69f; 
      margin-bottom: 30px;
    }
    .events-grid { 
      display: grid; 
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
      gap: 20px; 
      max-width: 1200px;
      margin: 0 auto;
    }
    .event-card { 
      background: #222; 
      border: 2px solid #333; 
      border-radius: 10px; 
      padding: 20px; 
      transition: border-color 0.3s ease, transform 0.3s ease;
    }
    .event-card:hover { 
      border-color: #69f; 
      transform: translateY(-5px);
    }
    .event-card a { 
      color: #69f; 
      text-decoration: none; 
      font-size: 1.2em;
      font-weight: bold;
    }
    .event-card a:hover { 
      color: #fff; 
    }
    .event-date {
      color: #888;
      font-size: 0.9em;
      margin-top: 10px;
    }
  </style>
</head>
<body>
<h1>Events Photo Galleries</h1>
<div class="events-grid">
EOF

  # Add event links to main index
  for event_dir in "$EVENTS_DIR"/*/; do
    if [[ -n "$event_dir" && -d "$event_dir" ]]; then
      event_name=$(basename "$event_dir")
      if is_event_directory "$event_name"; then
        date_part="${event_name:0:8}"
        name_part="${event_name:9}"
        formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
        echo "  <div class=\"event-card\">" >> "$events_index"
        echo "    <a href=\"$event_name/index.html\">$name_part</a>" >> "$events_index"
        echo "    <div class=\"event-date\">$formatted_date</div>" >> "$events_index"
        echo "  </div>" >> "$events_index"
      fi
    fi
  done

  cat >> "$events_index" <<EOF
</div>
</body>
</html>
EOF

    echo "✅ Main events index created: $events_index"
  else
    echo "✅ Main events index already up-to-date: $events_index"
  fi
}

# Main processing
echo "Processing events directory: $EVENTS_DIR"
if [[ "$FORCE_REGENERATE" == true ]]; then
  echo "🔄 Force regeneration enabled - all thumbnails will be recreated"
fi
if [[ "$USE_TIMESTAMPS" == true ]]; then
  echo "📅 Timestamp-based file renaming enabled"
else
  echo "📝 Simple sequential file renaming enabled"
fi

# Debug: List all directories found
echo "🔍 Found directories:"
for dir in "$EVENTS_DIR"/*/; do
  if [[ -d "$dir" ]]; then
    dirname=$(basename "$dir")
    echo "  - $dirname"
  fi
done
echo ""

# Global counters for final summary
total_events=0
processed_events=0
skipped_events=0
total_files_renamed=0
total_thumbnails_created=0
total_thumbnails_skipped=0
total_errors=0

# Process each event directory
echo "🔍 Starting main loop..."
for event_dir in "$EVENTS_DIR"/*/; do
  echo "🔍 Loop iteration with: $event_dir"
  if [[ -n "$event_dir" && -d "$event_dir" ]]; then
    event_name=$(basename "$event_dir")
    echo "🔍 Checking directory: $event_name"
    
    if is_event_directory "$event_name"; then
      ((total_events++))
      echo ""
      echo "=== Processing event: $event_name ==="
      
      # Step 3.1: Rename files if needed
      echo "  🔄 Starting file renaming..."
      echo "  📞 About to call rename_files_in_event with: $event_dir"
      rename_files_in_event "$event_dir"
      renamed_count=$?
      echo "  📞 Returned from rename_files_in_event"
      echo "  ✅ File renaming completed"
      
      # Ensure renamed_count is numeric
      renamed_count=${renamed_count:-0}
      if [[ "$renamed_count" =~ ^[0-9]+$ ]]; then
        ((total_files_renamed += renamed_count))
      fi
      
      # Step 3.2: Create gallery
      echo "  🔄 Starting gallery creation..."
      echo "  📞 About to call create_event_gallery with: $event_dir"
      create_event_gallery "$event_dir"
      echo "  📞 Returned from create_event_gallery"
      echo "  ✅ Gallery creation completed"
      
      echo "=== Completed: $event_name ==="
      echo ""
      ((processed_events++))
    else
      echo "Skipping non-event directory: $event_name"
      ((skipped_events++))
    fi
  fi
done

# Create main events index
create_events_index

echo ""
echo "📊 Summary:"
echo "  • Total directories found: $total_events"
echo "  • Event directories processed: $processed_events"
echo "  • Non-event directories skipped: $skipped_events"
echo ""
echo "📁 File Operations:"
echo "  • Files renamed: $total_files_renamed"
echo "  • Thumbnails created: $total_thumbnails_created"
echo "  • Thumbnails skipped (already up-to-date): $total_thumbnails_skipped"
echo "  • Errors encountered: $total_errors"
echo ""
echo "🎉 All done! Open $EVENTS_DIR/gallery.html in your browser to view all events."