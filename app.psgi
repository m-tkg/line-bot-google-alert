use LWP::UserAgent;
use Plack::Builder;
use Amon2::Lite;
use JSON qw/encode_json decode_json/;
use DateTime::Format::HTTP;

require 'setting.conf';
my $last_update_file = '/tmp/lastupdate';

post "/callback" => sub{
	my ($c) = @_;
	my $body = decode_json($c->req->content);
	my $target = $body->{result}[0]->{content}->{from};
	send_message($target, $target);
	return $c->create_response(200, ['Content-Type' => 'text/plain'], 'ok');
};

get "/news" => sub{
	my $c = shift;
	my $text = '';
	my $newest_date;
	my $last_update;
	my $ua = LWP::UserAgent->new;

	# === get update date
	if(-e $last_update_file){
		open FH, $last_update_file;
		$last_update = DateTime::Format::HTTP->parse_datetime(<FH>);
		close FH;
	}

	# === get news
	my $res = $ua->get('https://ajax.googleapis.com/ajax/services/feed/load?v=1.0&q='.$feed_url);
	if($res->is_success){
		# === parse news
		my $ret = decode_json($res->content);
		for my $particle (@{$ret->{responseData}->{feed}->{entries}}){
			my $dt = DateTime::Format::HTTP->parse_datetime($particle->{publishedDate});
			if(!defined($last_update) || DateTime->compare($dt, $last_update)>0){
				my $url = $particle->{link};
				$url =~ s/([^ 0-9a-zA-Z])/"%".uc(unpack("H2",$1))/eg;
				$url =~ s/ /+/g;
				$res = $ua->get('http://urx.nu/register.php?cmd=normal&expire=0&url='.$url);
				if($res->is_success){
					$res->content =~ /url\s*:\s*'([^']+)'/;
					$text .= $particle->{title}."\n".$1."\n-----\n";
				}
			}
			$newest_date = $dt if(!defined $newest_date || DateTime->compare($dt, $newest_date)>0);
		}

		# === LINE bot API
		send_message($target_mid, $text);
	}

	# === update date
	if(defined($newest_date)){
		open FH, '>'.$last_update_file;
		print FH DateTime::Format::HTTP->format_datetime($newest_date);
		close FH;
	}

	return $c->create_response(200, ['Content-Type' => 'text/plain'], 'ok');
};

sub send_message{
	my ($target, $text ) = @_;
	my $ua = LWP::UserAgent->new;
	my $api_req = HTTP::Request->new('POST', 'https://trialbot-api.line.me/v1/events');
	$api_req->header(
		'Content-Type' => 'application/json',
		'X-Line-ChannelID' => $channel_id,
		'X-Line-ChannelSecret' => $channel_secret,
		'X-Line-Trusted-User-With-ACL' => $mid
	);
	$api_req->content(encode_json(
		{
        	        to => [ $target],
       		        toChannel => 1383378250,
               		eventType => 138311608800106203,
			content => {
				contentType => 1,
				toType => 1,
				text => $text
			}
		}
	));
        $ua->request($api_req);
}

builder {
	__PACKAGE__->to_app();
};

