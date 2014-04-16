package PODWebView;
use Dancer ':syntax';

use Dancer::Plugin::Preprocess::Markdown;

use Cwd qw(abs_path);
use Pod::Simple::HTML;

our $VERSION = '0.1';

use Pod::Simple::HTML;
my $p = Pod::Simple::HTML->new;

get '/' => sub {
    template 'index', {
        file_size_limit => config->{app_settings}->{file_size_limit}
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
