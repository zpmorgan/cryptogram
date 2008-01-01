#!/usr/bin/perl
use strict;

use Gtk2 '-init';
use Gtk2::SimpleList;
use Text::Wrap;

my $alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
my $fortune;
my $key;
my $numColumns = 24;
my %encrypt;
my %decrypt;
my %guesses;

my $win = Gtk2::Window->new();
$win->signal_connect("delete_event", sub {Gtk2->main_quit} );

my $fields = q|x text | x $numColumns;
$fields =~ s/\s*$//; #rm space at end
my @fields = split(/\s+/, $fields);
my $fortuneView = Gtk2::SimpleList->new (@fields);  
@{$fortuneView->{data}} = (
          [ 'text', 1, 1.1],
          [ 'text', 2, 2.2]);

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

#set data in the simplelist
sub reloadFortuneView{
    
    $Text::Wrap::columns = $numColumns;
    #split into lines and then split each line into chars
    my @splitFortune = split ("\n", wrap('','',$fortune));
    @splitFortune = map { [split('',$_)] } @splitFortune;
    @{$fortuneView->{data}} = ();
    #$fortuneView->{data} = [];   #doesn't work. Something to do with tie?
    for my $line (@splitFortune){
        push @{$fortuneView->{data}}, [map {getGuess ($encrypt{$_} or $_)} @$line];
        push @{$fortuneView->{data}}, [map {$encrypt{$_} or $_} @$line];
        print @$line, "\n";
    }
}

sub new_puzzle{
    $fortune = uc get_fortune(50,100);
    gen_random_key;
    reloadFortuneView;
}
