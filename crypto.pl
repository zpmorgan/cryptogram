#!/usr/bin/perl -w
use strict;

use Gtk2 '-init';
#use Gtk2::SimpleList;  
use Gtk2::SimpleMenu;
use Text::Wrap;
sub TRUE{1} sub FALSE{0}

my $min_fortune=70;
my $max_fortune=120;
my $numColumns = 40;
my $alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
my $fortune;
my $key;
my $victorious = FALSE;
my %encrypt;
my %decrypt;
my %guesses;  #win when enough of %guesses is like %decrypt. (not all letters are used.)
my %guessLabels; #lists of (empty at first) labels in fortuneview
my @guessEntries; #list of 26 entries in guesstable
my %letterCount;  #unencrypted
my %enc_letterCount;
my $victory_message = 
    "Congratulations.\n You took 5 points from Jack Bauer. \nRun.";

my $win = Gtk2::Window->new();
$win->signal_connect("delete_event", sub {Gtk2->main_quit} );

my $fortuneView;
my $guessTable;


my $vbox = Gtk2::VBox->new(FALSE,0);
$win->add($vbox);

my $menu_tree = [
    _File => {
        item_type => '<Branch>',
        children => [
            _New => {
                item_type => '<StockItem>',
                callback => \&new_puzzle,
                callback_action => 0,
                accelerator => '<ctrl>N',
                extra_data => 'gtk-new',
            },
            _Cheat => {
                callback => \&cheat,
                callback_action => 1,
                callback_data => 'per entry cbdata',
                accelerator => '<ctrl>C',
            },
            _Quit => {
                item_type => '<StockItem>',
                callback => sub{Gtk2->main_quit},
                callback_action => 2,
                accelerator => '<ctrl>Q',
                extra_data => 'gtk-quit',
            },
        ]
     },
];
my $menu = Gtk2::SimpleMenu->new (
        menu_tree => $menu_tree,
        default_callback => sub {print "unimplemented\n"},
        user_data => 'user_data',
);

$vbox->pack_start($menu->{widget}, TRUE, FALSE, 0);
$win->add_accel_group($menu->{accel_group});
new_puzzle();

$win->show_all;
Gtk2->main();

sub new_puzzle{
    $victorious = FALSE;
    $fortune = uc get_fortune($min_fortune, $max_fortune);
    gen_random_key();
    count_letters();
    reload_crypto_tables();
}

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

sub count_letters{
    #count letters
    %letterCount = ();
    %enc_letterCount = ();
    for my $char (split '', $fortune){
        $letterCount{$char}++  if  $char =~ /[A-Z]/;
        $char = encrypt($char);
        $enc_letterCount{$char}++  if  $char =~ /[A-Z]/;
        $guesses{$char} = '';
    }
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
    #ensure a derangement
    for (0..$#alpha){
        if ($alpha[$_] eq $array[$_]) {
            gen_random_key();
            #warn 'key not deranged, setting another..';
            return;
        }
    }
}

sub getGuess{
    my $char = shift;
    return $char    if    $char !~ /[A-Z]/; #space, num, or punctuation
    return $guesses{$char}  if $guesses{$char};
    return '_';
}

sub encrypt{
    my $char = shift;
    return $char unless defined $encrypt{$char};
    return $encrypt{$char};
}
sub decrypt{
    my $char = shift;
    return $char unless defined $encrypt{$char};
    return $decrypt{$char};
}

#is for fortuneview:
sub insert_char_label{
    my ($lbl, $col, $row) = @_;
    $fortuneView->attach_defaults ($lbl, $col,$col+1, $row,$row+1);
    #print"$char $col $row\n";
}

#split into lines and then split each line into chars
sub get_fortune_chars{
    $Text::Wrap::columns = $numColumns;
    my @splitFortune = split ("\n", wrap('','',$fortune));
    @splitFortune = map { [split('',$_)] } @splitFortune;
    return @splitFortune;
}

#set data in the table
sub reloadFortuneView{
    %guessLabels = ();
    my @splitFortune = get_fortune_chars();
    for (my $rownum=0 ; $rownum<@splitFortune ; $rownum++){
        my @line=@{$splitFortune[$rownum]};
        for (my $colnum=0 ; $colnum<@line ; $colnum++){
            my $char=$line[$colnum];
            
            my $label1 = Gtk2::Label->new (getGuess ($encrypt{$char} or $char));
            insert_char_label ($label1, $colnum, 3*$rownum);
            push @{$guessLabels{$char}}, $label1;
            
            my $label2 = Gtk2::Label->new (encrypt($char));
            insert_char_label ($label2, $colnum, 3*$rownum+1);
        }
        insert_char_label(Gtk2::Label->new(' '), 0, 3*$rownum+2)
     #   print @line, "\n";
    }
}

sub reloadGuessTable{
    my @alpha = split //, $alpha; #all uc letters
    for (0..$#alpha){
        my $char = $alpha[$_];
        my $guessEntry = Gtk2::Entry->new_with_max_length (1);
        
        $guessEntry->set_size_request(20,20);
        #my $guess = getGuess($char) or '';
        my $guess = '';
        $guessEntry->set_text ($guess);
        $guessTable->attach_defaults ($guessEntry, $_,$_+1, 0,1);
        $guessEntry->signal_connect("changed", \&make_guess, $char);
        $guessEntries[$_] = $guessEntry;
        
        my $lbl = Gtk2::Label->new ($char);
        $guessTable->attach_defaults ($lbl, $_,$_+1, 1,2);
    }
}

sub make_guess{
    my ($entry, $char) = @_;
    my $guess = $entry->get_text;
    #warn "$char $guess";
    if ($guess =~ /[A-Za-z]/){
        $guesses{$char} = uc $guess;
        $entry->set_text(uc $guess);
    }
    else{
        $entry->set_text('');
        delete $guesses{$char}
    }
    #adjust fortuneview to new guess
    #warn keys %guessLabels;
    for my $lbl ( @{ $guessLabels {decrypt($char)} } ){
        my $text = $guesses{$char} ? $guesses{$char} : '_';
        $lbl->set_text($text)
    }
    if (detectVictory()){
        doVictory()
    }
}
sub detectVictory{
    return 0 if $victorious;
    my $lettersCorrect = 0;
    for my $char (keys %enc_letterCount){
        # print ++$lettersCorrect, $char, ' ', $guesses{$char}, ' ', $decrypt{$char},"\n";
        return 0 unless defined $guesses{$char};
        return 0 if $guesses{$char} ne $decrypt{$char}
    }
    return 1;
}

sub doVictory{
    $victorious = TRUE;
    my $victWin = Gtk2::Window->new();
    my $label = Gtk2::Label->new($victory_message);
    my $okbutton = Gtk2::Button->new("ok");
    $okbutton->signal_connect("clicked", sub {$victWin->destroy} );
    my $vb = Gtk2::VBox->new(FALSE,0);
    $vb->pack_start($label, TRUE, FALSE, 0);
    $vb->pack_start($okbutton, TRUE, FALSE, 0);
    $victWin->add($vb);
    $victWin->show_all;
}

sub cheat{
    my $cheatWin = Gtk2::Window->new();
    my $label = Gtk2::Label->new($fortune);
    my $okbutton = Gtk2::Button->new("ok");
    $okbutton->signal_connect("clicked", sub {$cheatWin->destroy} );
    my $vb = Gtk2::VBox->new(FALSE,0);
    $vb->pack_start($label, TRUE, FALSE, 0);
    $vb->pack_start($okbutton, TRUE, FALSE, 0);
    $cheatWin->add($vb);
    $cheatWin->show_all;
    
    
}
