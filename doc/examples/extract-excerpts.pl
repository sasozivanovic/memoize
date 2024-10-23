while (<>) {
    if ($in_listing) {
	if (/^ *% *\\end\{listingregion\}/) {
	    # print the collected lines, automatically deindented
	    $indent = -1;
	    for my $line (@lines) {
		$line =~ /^ */;
		$current_indent = length($&);
		$indent = -1 ? $current_indent : min($indent, $current_indent);
	    }
	    for $line (@lines) {
		print LISTING substr($line, $indent);
	    }
	    # close the excerpt file
	    close LISTING;
	    $in_listing = 0;
	} else {
	    # append to the list
	    push(@lines, $_);
	}
    } elsif (/^ *% *\\begin\{listingregion\}\{([^}]*)\}/) {
	# upon encountering "  % \begin{listingregion}{<filename>}",
	# open the excerpt file, initialize the excerpt list
	open LISTING, ">$1.excerpt";
	$in_listing = 1;
	@lines = ();
    }
}
