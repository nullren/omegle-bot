#!/usr/bin/env perl

## only 3 cpan modules installed: POE::Components::IRC, 
## POE::Components::Omegle, and REST::Google::Translate
##  there are a few "settings" that can be changed
## like nick, the nick to change to during omegle chat
## and server and channel... 
##
## license: i am not responsible for anything. ever. or whatever.
##
##
## TO RUN:
## execute this script with 4 arguments in this order:
##      $ perl omegle-bot.pl <botname> <strangername> <ircserver> <ircchannel>
##    
## 

use strict;
use warnings;
use Switch;

use POE qw(Component::IRC Component::Omegle Wheel::ReadLine);

####### #######
####### #######

my $ORIGINALNICK = shift || 'nullbot';
my $OMEGLENICK = shift || 'stranger';

my $NICK = $ORIGINALNICK;

my $USERNAME = 'banana';
my $IRCNAME = 'ask me for help';

my $SERVER = shift || 'irc.foonetic.net';
my $CHANNEL = shift || '#boats';

my $perl_location = `which perl`; chomp $perl_location;
my $script_location = "$0";

####### #######

my $IRC_ALIAS = 'butt';

my $OMEGLE_SESSION = 0;
my $omegle;
my $rl;

my $LAZY = 0;
my @NAMES = ();
my @FOCUS = ();

sleep 1; #time to respawn


my $irc = POE::Component::IRC->spawn(
    nick => $NICK,
    ircname => $IRCNAME,
    username => $USERNAME,
    server => $SERVER,
    alias => $IRC_ALIAS, ) or die "uhhhhhh $!";
    
POE::Session->create( inline_states => {
    _start => sub {
        $_[KERNEL]->post( $IRC_ALIAS => register => 'all' );
        $_[KERNEL]->post( $IRC_ALIAS => connect => {} );
        $_[HEAP]->{readline} = POE::Wheel::ReadLine->new(InputEvent => 'got_input');
        $rl = $_[HEAP]->{readline};
    },
    irc_001 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => join => $CHANNEL );
        $rl->put("Joined channel $CHANNEL on $SERVER");
        $rl->addhistory("respawn");
        $rl->get("$NICK> ");
    },
    got_input => sub {
        my ($input,$exception) = @_[ARG0,ARG1];
        if( $input eq 'respawn' ){
            exec $perl_location, $script_location, $ORIGINALNICK, $OMEGLENICK, $SERVER, $CHANNEL;
            exit 0;
        }
        if( defined $input ){
            $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => $input );
            $rl->addhistory($input);
        }
        if( $exception eq 'interrupt'){
            delete $_[HEAP]->{readline};
            undef $rl;
            $_[KERNEL]->yield(unregister => 'all');
            $_[KERNEL]->yield('shutdown');
            exit 0;
        }
        
        $rl->get("$NICK> ");
    }, 
    irc_public => sub {
        my ($kernel, $heap, $who, $where, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
        my $nick    = (split /!/, $who)[0];
        my $channel = $where->[0];
        my $ts      = scalar localtime;
        $rl->put( "$ts <$nick> $msg");
        
        if (my ($what) = $msg =~ /^$NICK[:,] (.+)/) {
            $omegle->say($what) if $OMEGLE_SESSION;
            push @FOCUS, $nick if $OMEGLE_SESSION; # they have focus, so whatever they say, goes to stranger
            $rl->put("(( @FOCUS )) { @NAMES }");

            if( !$OMEGLE_SESSION and $what =~ /^help/i ){
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "commands are ;start, ;stop, ;respawn. after ;start-ing and inviting an omegle stranger, the conversation can be ;stop-ped. if i become unresponsive, try ;respawn-ing me.");
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "during a conversation, the omegle stranger can only hear you if you speak to $OMEGLENICK");
            }
        } elsif (my ($cmd) = $msg =~ /^;(\w+)/){
            if( $cmd eq "start" and ! $OMEGLE_SESSION){
                $LAZY = 0;
                $LAZY = 1 if $msg =~ /lazy/;
                $_[KERNEL]->yield( "my_omegle" );
            }elsif ( $cmd eq "start" and $OMEGLE_SESSION ){
                #$omegle->{async}->poke;
                $omegle->flush_events;
                $omegle->disconnect();
                $_[KERNEL]->post($IRC_ALIAS => ctcp => $CHANNEL => "ACTION disconnects" ); 
                $OMEGLE_SESSION = 0;
                @FOCUS = ();
                undef $omegle;
                
                sleep 2;
                
                $LAZY = 0;
                $LAZY = 1 if $msg =~ /lazy/;
                $_[KERNEL]->yield( "my_omegle" );
            }elsif ( $cmd eq "stop" and $OMEGLE_SESSION ){
                #$omegle->{async}->poke;
                $omegle->flush_events;
                $omegle->disconnect();

                $_[KERNEL]->post($IRC_ALIAS => ctcp => $CHANNEL => "ACTION disconnects" ); 

                # change nick :D so its OBVIOUS we're in omegle mode
                $_[KERNEL]->post( $IRC_ALIAS => nick => $ORIGINALNICK );
                $NICK = $ORIGINALNICK;
                $OMEGLE_SESSION = 0;
                @FOCUS = ();
                undef $omegle;
            }elsif ( $cmd eq "respawn" ){
                exec $perl_location, $script_location, $ORIGINALNICK, $OMEGLENICK, $SERVER, $CHANNEL;
                exit 0;
            }elsif ( $cmd eq "die" ){
                exit 0;
            }elsif ( $cmd eq "help" ){
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "commands are ;start, ;stop, ;respawn. after ;start-ing and inviting an omegle stranger, the conversation can be ;stop-ped. if i become unresponsive, try ;respawn-ing me.");
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "during a conversation, the omegle stranger can only hear you if you speak to $OMEGLENICK");
            }

        } elsif ( $LAZY and grep { $nick eq $_ } @FOCUS ) {
            $rl->put("i'm listening to $nick");
            if( my ($who, $what) = $msg =~ /^([^:, ]+)[:,] (.+)/ and grep { $1 eq $_ } @NAMES){
                $rl->put("who is this \"$who\" he think he's talking to");
                    $rl->put("aww, he doesn't love us");
                    foreach (0 .. $#FOCUS){
                        delete $FOCUS[$_] if $FOCUS[$_] eq $nick;
                        $rl->put("lets delete him, he's not talking to me");
                    }
            } else {
                $rl->put("he has something good to say");
                $rl->put("(( @FOCUS )) { @NAMES }");
                $omegle->say($msg);
            }    
        }
    },
    irc_433 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => nick => $NICK . $$%1000 );
    },
    # 353 part quit kick join
    irc_353 => sub {
        @NAMES = split / /, (split /:/, $_[ARG1])[1];
        s/^[@%+]// foreach @NAMES;
        $rl->put("(( @FOCUS )) { @NAMES }");
    },
    irc_join => sub {
        push @NAMES, (split /!/, $_[ARG0])[0];
        $rl->put("(( @FOCUS )) { @NAMES }");
    },
    ( map { ; "irc_$_" => sub {
        my $nick = (split /!/, $_[ARG0])[0];
        foreach (0 .. $#NAMES){
            delete $NAMES[$_] if $NAMES[$_] eq $nick;
        }
        $rl->put("(( @FOCUS )) { @NAMES }");
    }} qw(part quit) ),
    irc_kick => sub {
        my $was_kicked = $_[ARG2];
        my $kicked_by  = $_[ARG3];
        
        exit 0 if $was_kicked eq $NICK;
        
        foreach (0 .. $#NAMES){
            delete $NAMES[$_] if $NAMES[$_] eq $was_kicked;
        }
        $rl->put("(( @FOCUS )) { @NAMES }");
    },
    ( map { ; "$_" => sub {} } qw(_child irc_ping) ),
    _default => sub {
        $rl->put(sprintf "%s: session %s caught an unhandled %s event.", scalar localtime(), $_[SESSION]->ID, $_[ARG0]);
        $rl->put("$_[ARG0]: ".join(" ", map({"ARRAY" eq ref $_ ? "[@$_]" : "$_"} @{$_[ARG1]})));
        0;    # false for signals
    },
    my_omegle => sub {
        my $session = $_[SESSION];
        POE::Session->create(
            inline_states => {
                _start => sub {
                    my ($heap) = $_[HEAP];
                    my $om = POE::Component::Omegle->new;
                    
                    $om->set_callback(connect => 'om_connect');
                    $om->set_callback(chat => 'om_chat');
                    $om->set_callback(disconnect => 'om_disconnect');
                    
                    $heap->{om} = $om;
                    
                    $om->start_chat;
                    $poe_kernel->delay_add( poke => 0.1, $om );
                },
                poke => sub {
                    my ($kernel, $heap, $om) = @_[KERNEL, HEAP, ARG0];
                    
                    $om->poke;
                    $poe_kernel->delay_add( poke => 0.1, $om );
                },
                om_connect => sub {
                    my $om = $_[HEAP]->{om};
                    
                    $rl->put( "Omegle: Stranger connected");
                    
                    # change nick :D so its OBVIOUS we're in omegle mode
                    $_[KERNEL]->post( $IRC_ALIAS => nick => $OMEGLENICK );
                    $_[KERNEL]->post($IRC_ALIAS => ctcp => $CHANNEL => "ACTION has connected" ); 
                    $NICK = $OMEGLENICK;

                    $OMEGLE_SESSION = 1;
                    $omegle = $om;
                },
                om_chat => sub {
                    my ($cb_args) = $_[ARG1];
                    my ($om, $chat) = @$cb_args;
                    
                    $rl->put( "Omegle: STRANGER >> $chat" );
                    $_[KERNEL]->post($IRC_ALIAS => privmsg => $CHANNEL => "$chat" );
                },
                om_disconnect => sub {
                    $rl->put( "Omegle: Stranger disconnected" );
                    $_[KERNEL]->post($IRC_ALIAS => ctcp => $CHANNEL => "ACTION disconnects" ); 

                    # change nick :D so its OBVIOUS we're in omegle mode
                    $_[KERNEL]->post( $IRC_ALIAS => nick => $ORIGINALNICK );
                    $NICK = $ORIGINALNICK;
                    @FOCUS = ();

                    $OMEGLE_SESSION = 0;
                    undef $omegle;
                },
            },
        );
    },
},);

POE::Kernel->run;
