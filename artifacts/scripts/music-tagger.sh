# ... (Lines 1-76 are the same: Configuration, safe_find, Step 1, Step 2)

# 4. Apply the tag using the appropriate tool
echo -e "\nPreparing to add comment: '$new_comment'"

file_extension=$(echo "$selected_song" | awk -F. '{print tolower($NF)}')
SUCCESS_FLAG=1 # Default to Fail (1)

if [[ "$file_extension" == "m4a" || "$file_extension" == "mp4" ]]; then
    
    # ... (M4A/MP4 Logic with AtomicParsley - unchanged) ...

elif [[ "$file_extension" == "mp3" || "$file_extension" == "flac" ]]; then

    # ... (MP3/FLAC Logic with eyeD3 - unchanged) ...

elif [[ "$file_extension" == "opus" ]]; then

    # Check if opustags is installed
    if ! command -v opustags &> /dev/null; then
        echo -e "\n❌ ERROR: opustags not found. Install it to tag .$file_extension files (e.g., sudo apt install opustags)."
        exit 1
    fi

    echo "Using opustags for OPUS..."
    
    # opustags:
    # --add: adds a tag, appending it if the tag key already exists (which is what we want for comments).
    # The format is TAG=VALUE.
    # The tag key for a standard comment in Vorbis Comments is 'COMMENT'.
    
    opustags --add "COMMENT=$new_comment" "$selected_song"

    SUCCESS_FLAG=$?
    if [ $SUCCESS_FLAG -eq 0 ]; then
        echo -e "\n✅ Success: Comment added to $(basename "$selected_song")"
        echo "Current Tags (Comment Field):"
        # Display ONLY the comments for verification
        opustags --output - "$selected_song" | grep "comment="
    else
        echo -e "\n❌ Error: Failed to apply tag with opustags (Error Code: $SUCCESS_FLAG)."
    fi

else
    echo -e "\n⚠️ Warning: Tagging for file type .$file_extension is not supported. Skipping."
    exit 1
fi