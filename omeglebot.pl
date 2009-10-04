#!/usr/bin/env perl

## only 3 cpan modules installed: POE::Components::IRC, 
## POE::Components::Omegle, and REST::Google::Translate
##  there are a few "settings" that can be changed
## like nick, the nick to change to during omegle chat
## and server and channel... 
##
## license: i am not responsible for anything. ever. or whatever.
##
## it would be cool if people updated changes here http://pastie.org/pastes/585642/edit
##
## TO RUN:
## execute this script:
##      $ perl stranger1.pl 'irc.foonetic.net' '#omeglebots' 'omegleB' 'omegleA: ' 'omegleB'
##    
## 

use strict;
use warnings;
use Switch;

use POE qw(Component::IRC Component::Omegle);

####### #######
####### #######

my $SERVER = shift || 'irc.foonetic.net';
my $CHANNEL = shift || '#omeglebots';

my $ORIGINALNICK = shift || 'omegleA';

#or '' for noone, but stranger is the other bot
my $CHATPREFIX = shift || 'omegleB: '; 
my $HEARSFROM = shift || 'omegleC';

# if set to 1, bot will change nicks to OMEGLENICK during session
my $OMEGLENICK = shift || 'stranger1';
my $changenicks = 0;

my $AUTORELOAD = 1;

my $NICK = $ORIGINALNICK;
my $ATTN = \$HEARSFROM;

my $USERNAME = 'banana';
my $IRCNAME = 'ask me for help';


my $perl_location = `which perl`; chomp $perl_location;
my $script_location = "$0";

####### #######

my $IRC_ALIAS = 'butt';

my $OMEGLE_SESSION = 0;
my $omegle;

sleep 3; #time to respawn


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
    },
    irc_001 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => join => $CHANNEL );
    },
    irc_433 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => nick => $NICK . $$%1000 );
    },
    irc_kick => sub {
        exit 0;
    },
    irc_public => sub {
        my ($kernel, $heap, $who, $where, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
        my $nick    = (split /!/, $who)[0];
        my $channel = $where->[0];
        my $ts      = scalar localtime;
        print " [$ts] <$nick:$channel> $msg\n";
        
        if (my ($what) = $msg =~ /^$$ATTN[:,]? (.+)/) {
            $omegle->say($what) if $OMEGLE_SESSION;

            if( !$OMEGLE_SESSION and $what =~ /^help/i ){
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "commands are ;start, ;stop, ;respawn. after ;start-ing and inviting an omegle stranger, the conversation can be ;stop-ped. if i become unresponsive, try ;respawn-ing me.");
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "during a conversation, the omegle stranger can only hear you if you speak to $OMEGLENICK");
            }
        } elsif (my ($cmd) = $msg =~ /^;(\w+)/){
            if( $cmd eq "start" and ! $OMEGLE_SESSION){
                $_[KERNEL]->yield( "my_omegle" );
            }elsif ( $cmd eq "stop" and $OMEGLE_SESSION ){
                #$omegle->{async}->poke;
                $omegle->flush_events;
                $omegle->disconnect();

                # change nick :D so its OBVIOUS we're in omegle mode
                if( $changenicks ){
                    $_[KERNEL]->post( $IRC_ALIAS => nick => $ORIGINALNICK );
                    $NICK = $ORIGINALNICK;
                } else {
                    $_[KERNEL]->post( $IRC_ALIAS => ctcp => $CHANNEL => "ACTION disconnected" );
                }
                $OMEGLE_SESSION = 0;
                undef $omegle;
                
                if( $AUTORELOAD ){
                    sleep 3;
                    $_[KERNEL]->yield( "my_omegle" );
                }
            }elsif ( $cmd eq "respawn" ){
                exec $perl_location, $script_location, $SERVER, $CHANNEL, $ORIGINALNICK, $CHATPREFIX, $HEARSFROM, $OMEGLENICK;
                exit 0;
            }elsif ( $cmd eq "die" ){
                exit 0;
            }elsif ( $cmd eq "help" ){
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "commands are ;start, ;stop, ;respawn. after ;start-ing and inviting an omegle stranger, the conversation can be ;stop-ped. if i become unresponsive, try ;respawn-ing me.");
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $CHANNEL => "during a conversation, the omegle stranger can only hear you if you speak to $OMEGLENICK");
            }

        }
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
                    
                    print "Omegle: Stranger connected\n";
                    
                    # change nick :D so its OBVIOUS we're in omegle mode
                    if( $changenicks ){
                        $_[KERNEL]->post( $IRC_ALIAS => nick => $OMEGLENICK );
                        $NICK = $OMEGLENICK;
                    } else {
                        $_[KERNEL]->post( $IRC_ALIAS => ctcp => $CHANNEL => "ACTION connected" );
                    }

                    $OMEGLE_SESSION = 1;
                    $omegle = $om;
                },
                om_chat => sub {
                    my ($cb_args) = $_[ARG1];
                    my ($om, $chat) = @$cb_args;
                    
                    print "Omegle: STRANGER >> $chat\n";
                    $_[KERNEL]->post($IRC_ALIAS => privmsg => $CHANNEL => "$CHATPREFIX$chat" );
                },
                om_disconnect => sub {
                    print "Omegle: Stranger disconnected\n";

                    # change nick :D so its OBVIOUS we're in omegle mode
                    if( $changenicks ){
                        $_[KERNEL]->post( $IRC_ALIAS => nick => $ORIGINALNICK );
                        $NICK = $ORIGINALNICK;
                    } else {
                        $_[KERNEL]->post( $IRC_ALIAS => ctcp => $CHANNEL => "ACTION disconnected" );
                    }

                    $OMEGLE_SESSION = 0;
                    undef $omegle;
                    if( $AUTORELOAD ){
                        sleep 3;
                        $_[KERNEL]->yield( "my_omegle" );
                    }
                },
            },
        );
    },
    _child => sub {},
    _default => sub {
        #printf "%s: session %s caught an unhandled %s event.\n",
        #    scalar localtime(), $_[SESSION]->ID, $_[ARG0];
#        print "$_[ARG0]: ",
#            join(" ", map({"ARRAY" eq ref $_ ? "" : "$_"} @{$_[ARG1]})),
#            "\n";
        0;    # false for signals
    },
},);

POE::Kernel->run;
