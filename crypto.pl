#!/usr/bin/perl
use strict;

use Gtk2 '-init';
use Gtk2::SimpleList;
use Text::Wrap;

my $alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
my $fortune;
my $key;
my $numColumns = 34;
my %encrypt;
my %decrypt;
my %guesses;

my $win = Gtk2::Window->new();
$win->signal_connect("delete_event", sub {Gtk2->main_quit} );

my $fortuneView = Gtk2::Table->new(4, $numColumns);

new_puzzle();
$win->add($fortuneView);

$win->show_all;
Gtk2->main();

sub get_fortune{
    my ($min,$max) = @_;
    while(1){
        my $fortune = `fortune`;
        next if length ($fortune) < $min;
        next if length ($fortune) > $max;
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
            insert_char_label (getGuess ($encrypt{$char} or $char), $colnum, 2*$rownum);
            insert_char_label (encrypt($char), $colnum, 2*$rownum+1);
        }
        print @line, "\n";
    }
}

sub new_puzzle{
    $fortune = uc get_fortune(50,100);
    gen_random_key;
    reloadFortuneView;
}
