#!/usr/bin/perl -w
use strict;

use Gtk2 '-init';
#use Gtk2::SimpleList;  
use Gtk2::SimpleMenu;
use Text::Wrap;
sub TRUE{1} sub FALSE{0}

my $min_fortune=80;
my $max_fortune=130;
my $fortune_command = "fortune -n $min_fortune -l";
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

Gtk2->main();

sub new_puzzle{
    $victorious = FALSE;
    %guesses = ();
    $fortune = uc get_fortune($min_fortune, $max_fortune);
    gen_random_key();
    count_letters();
    reload_crypto_tables();
}

sub reload_crypto_tables{
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
        $guesses{$char} = '' if $char  =~ /[A-Z]/;
    }
}    

sub get_fortune{
    my ($min,$max) = @_;
    while(1){
        my $fortune = `$fortune_command`;
        next if length ($fortune) < $min;
        next if length ($fortune) > $max;
        $fortune =~ s/\t/   /g; #tabs to (3) spaces
        $fortune =~ s/\n(\S)/ $1/g; #newlines to 1 space, unless there's space after it.
        return $fortune;
    }
}

sub gen_random_key{
    ####sub fisher_yates_shuffle {
    my @array = split ("", $alpha);
    my @alpha = @array;
    for (my $i = @array; --$i; ) {
        my $j = int rand ($i+1);
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
sub setGuessBgColor{
    my ($char, $color) = @_;
    my $widget = $guessEntries[ord($char) - ord('A')];
    $color = Gtk2::Gdk::Color->parse ($color);
    $widget->modify_base('normal', $color);
    $widget->show_all();
}
#letters never represent themselves. Blue when people guess otherwise.
#letter representations are one-to-one. Yellow when that is violated.
my %blues;
my %yellows;
sub set_entry_conflicts{
    #key and guess should be different
    my %sameAsGuess;
    for (keys %guesses){
        if ($_ eq $guesses{$_}){
            $sameAsGuess{$_}=1;
            unless ($blues{$_}){ 
                setGuessBgColor($_, 'lightblue');
                $blues{$_} = 1;
            }
        }
    }
    for (keys %blues){
        unless ($sameAsGuess{$_}){
            setGuessBgColor($_, 'white');
            setGuessBgColor($_, 'yellow') if $yellows{$_};
            delete $blues{$_};
        }
    }
    #only one-to-one guesses
    my %multiple_guesses;
    for (values %guesses){
        next unless defined $_;
        $multiple_guesses{$_}++;
        #print $_;
    }
    #print %multiple_guesses;
    for my $key (keys %guesses){
        my $guess = $guesses{$key};
        next unless $guess;
        next unless defined $multiple_guesses{$guess};
        next unless ($multiple_guesses{$guess} > 1);
        next if $yellows{$key};
        #warn "$key $guess $multiple_guesses{$guess}";
        setGuessBgColor($key, 'yellow');
        $yellows{$key} = 1;
    }
 #   warn join ' ', keys %guesses;
 #   warn join ' ', values %guesses;
 #   warn join ' ', keys %multiple_guesses;
 #   warn join ' ', values %multiple_guesses;
    #unyellow:
    for (keys %yellows){
        next if $guesses{$_} and $multiple_guesses{$guesses{$_}} > 1;
        setGuessBgColor($_, 'white');
        setGuessBgColor($_, 'lightblue') if $blues{$_};
        delete $yellows{$_};
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
    set_entry_conflicts();
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
