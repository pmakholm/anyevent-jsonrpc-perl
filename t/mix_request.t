use Test::Base;

plan tests => 8;

use Test::TCP;
use AnyEvent::JSONRPC::Lite;
use AnyEvent::JSONRPC::Lite::TCPServer;

my $port = empty_port;

my $cv = AnyEvent->condvar;

my $server = AnyEvent::JSONRPC::Lite::TCPServer->new( port => $port );

my $waits = [ undef, rand(2), rand(2), rand(2), rand(2) ];
my $exit = 0;
my @obj;

$server->reg_cb(
    wait => sub {
        my ($r, $params) = @_;
        my ($num, $wait) = @$params;

        is( $waits->[$num], $wait, "Num $num will wait for $wait seconds ok");

        my $w; $w = AnyEvent->timer(
            after => $wait,
            cb    => sub {
                $r->result($wait);
                if (++$exit >= 4) {
                    my $w = AnyEvent->timer(
                        after => 0.3,
                        cb    => sub { $cv->send },
                    );
                    push @obj, $w;
                }
            },
        );
        push @obj, $w;
    },
);

my $client = AnyEvent::JSONRPC::Lite->new( host => '127.0.0.1', port => $port );

my $cv1 = $client->call( wait => '1', $waits->[1] );
my $cv2 = $client->call( wait => '2', $waits->[2] );
my $cv3 = $client->call( wait => '3', $waits->[3] );
my $cv4 = $client->call( wait => '4', $waits->[4] );

$cv1->cb(sub { is(shift->recv->{result}, $waits->[1], "cv1 waited $waits->[1] seconds ok") });
$cv2->cb(sub { is(shift->recv->{result}, $waits->[2], "cv2 waited $waits->[2] seconds ok") });
$cv3->cb(sub { is(shift->recv->{result}, $waits->[3], "cv3 waited $waits->[3] seconds ok") });
$cv4->cb(sub { is(shift->recv->{result}, $waits->[4], "cv4 waited $waits->[4] seconds ok") });

$cv->recv;