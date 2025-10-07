function copy_to_clipboard
    set file_name $argv[1]
    if type -q pbcopy
        cat $file_name | pbcopy
    else if type -q xclip
        cat $file_name | xclip -selection clipboard
    else if type -q clip
        cat $file_name | clip
    else if type -q wl-copy
        cat $file_name | wl-copy
    else
        echo "Clipboard tool not found, couldn't save $file_name"
    end
end

function copy_diff
    set file_name $argv[1]
    git diff --cached >$file_name

    if test -s $file_name
        echo "Generating commit message..."
    else
        echo "No changes detected. Please stage some files before using magic_diff."
        rm $file_name # Clean up the empty diff file
    end
end

function magic_diff
    set timestamp (date +"%Y%m%d_%H%M%S")
    set diff_file_name (mktemp /tmp/magic_diff_staged_diff.$timestamp.txt)
    set commit_file_name (mktemp /tmp/magic_diff_commit.$timestamp.txt)
    copy_diff $diff_file_name

    if test -f $diff_file_name
        set diff_content (cat $diff_file_name)

        # Check llm command existence
        if not type -q llm
            echo "llm command not found. Please ensure it's installed and in your PATH."
        end

        llm "Generate a git commit message based on the following diff. Here is the diff: $diff_content" >$commit_file_name

        copy_to_clipboard $commit_file_name
        echo "Message copied to clipboard"

        rm $diff_file_name

        if test -f $commit_file_name
            rm $commit_file_name
        end
    else
        echo "Failed to create or find diff file."
    end
end
