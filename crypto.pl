#!/usr/bin/perl
use strict;

use Gtk2 '-init';
use Gtk2::SimpleList;
use Text::Wrap;
sub TRUE{1} sub FALSE{0}

my $alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
my $fortune;
my $key;
my $numColumns = 34;
my %encrypt;
my %decrypt;
my %guesses;# = qw|A A B B C V F D|;

my $win = Gtk2::Window->new();
$win->signal_connect("delete_event", sub {Gtk2->main_quit} );

my $fortuneView;
my $guessTable;


my $vbox = Gtk2::VBox->new(FALSE,0);
$win->add($vbox);

new_puzzle();

$win->show_all;
Gtk2->main();

sub reload_crypto_tables{ #after every guess
    $fortuneView->destroy if defined $fortuneView;
    $guessTable->destroy if defined $guessTable;
    $fortuneView = Gtk2::Table->new(6, $numColumns);
    $guessTable = Gtk2::Table->new(2, 26, TRUE);
    $vbox->pack_start($fortuneView, TRUE, FALSE, 0);
    $vbox->pack_start($guessTable, TRUE, FALSE, 0);
    reloadFortuneView();
    reloadGuessTable();
    $win->show_all;
}

sub new_puzzle{
    $fortune = uc get_fortune(50,100);
    gen_random_key();
    reload_crypto_tables();
}

sub get_fortune{
    my ($min,$max) = @_;
    while(1){
        my $fortune = `fortune`;
        next if length ($fortune) < $min;
        next if length ($fortune) > $max;
        $fortune =~ s/\t/   /; #tabs to (3) spaces
        $fortune =~ s/\n\S/ /; #newlines to 1 space, unless there's space after it.
        return $fortune;
    }
}

sub gen_random_key{
    ####sub fisher_yates_shuffle {
    my @array = split ("", $alpha);
    my @alpha = @array;
    for (my $i = @array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @array[$i, $j] = @array[$j, $i];
    }
    for (0..$#alpha){
        $decrypt{$alpha[$_]} = $array[$_];
        $encrypt{$array[$_]} = $alpha[$_];
    }
}

sub getGuess{
    my $char = shift;
    return $char    if    $char !~ /[A-Z]/; #space, num, or punctuation
    return $guesses{$char}  if  defined $guesses{$char};
    return '_';
}

sub encrypt{
    my $char = shift;
    return $char unless defined $encrypt{$char};
    return $encrypt{$char};
}

sub insert_char_label{
    my ($char, $col, $row) = @_;
    my $lbl = Gtk2::Label->new($char);
    $fortuneView->attach_defaults ($lbl, $col,$col+1, $row,$row+1);
    #print"$char $col $row\n";
}

#set data in the table
sub reloadFortuneView{
    $Text::Wrap::columns = $numColumns;
    #split into lines and then split each line into chars
    my @splitFortune = split ("\n", wrap('','',$fortune));
    @splitFortune = map { [split('',$_)] } @splitFortune;
    #someone should clear fortuneview
    for (my $rownum=0 ; $rownum<@splitFortune ; $rownum++){
        my @line=@{$splitFortune[$rownum]};
        for (my $colnum=0 ; $colnum<@line ; $colnum++){
            my $char=$line[$colnum];
            insert_char_label (getGuess ($encrypt{$char} or $char), $colnum, 3*$rownum);
            insert_char_label (encrypt($char), $colnum, 3*$rownum+1);
        }
        insert_char_label(' ', 0, 3*$rownum+2)
     #   print @line, "\n";
    }
}

sub reloadGuessTable{
    my @alpha = split //, $alpha; #all uc letters
    for (0..$#alpha){
        my $char = $alpha[$_];
        my $guessEntry = Gtk2::Entry->new_with_max_length (1);
        $guessEntry->set_size_request(20,20);
        $guessEntry->set_text(getGuess($char));
        $guessTable->attach_defaults ($guessEntry, $_,$_+1, 0,1);
        $guessEntry->signal_connect("activate", \&make_guess, $char);
        
        my $lbl = Gtk2::Label->new ($char);
        $guessTable->attach_defaults ($lbl, $_,$_+1, 1,2);
    }
}

sub make_guess{
    my ($entry, $char) = @_;
    my $guess = $entry->get_text;
    if ($guess =~ /[A-Za-z]/){
        $guesses{$char} = uc $guess
    }
    else{
        delete $guesses{$char}
    }
    reload_crypto_tables();
}
