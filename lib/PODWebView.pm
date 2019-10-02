package PODWebView;
use Dancer ':syntax';

use Dancer::Plugin::Preprocess::Markdown;

use Cwd qw(abs_path);
use Pod::Simple::HTML;

our $VERSION = '0.2';

use Pod::Simple::HTML;
my $p = Pod::Simple::HTML->new;

get '/' => sub {
    my $url = param 'url';
    my $url_content;
    if ($url) {
        require HTTP::Tiny;
        my $response = HTTP::Tiny->new->get($url);
        if ($response->{success}) {
            require Encode;
            require JavaScript::Value::Escape;
            $url_content = JavaScript::Value::Escape::js(
                Encode::decode('UTF-8',$response->{content})
            );
        }
    }
    template 'index', {
        file_size_limit => config->{app_settings}->{file_size_limit},
        pod_data => $url_content ? "'$url_content'" : "''",
    };
};

post '/podhtml' => sub {
    if (request->is_ajax) {
        eval {
            return process_pod(params->{pod});
        }
        or do {
            # We can recover from some errors by creating a new instance of the
            # parser object, so let's try that.
            $p = Pod::Simple::HTML->new;
            return process_pod(params->{pod});
        };
    }
    else {
        return error("Not allowed", 403);
    }
};

sub process_pod {
    my ($pod) = @_;

    $p->output_string(\my $html);
    $p->parse_string_document($pod);
    $p->reinit;

    return $html;
}

true;
