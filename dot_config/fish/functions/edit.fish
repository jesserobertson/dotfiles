function edit
    if string-empty $argv
        $EDITOR
        return
    end

    $EDITOR $argv
end
