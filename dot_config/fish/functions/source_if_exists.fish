function source_if_exists
    if test -e $argv
        source $argv
    else
	echo "File '$argv' doesn't exist"
    end
end
