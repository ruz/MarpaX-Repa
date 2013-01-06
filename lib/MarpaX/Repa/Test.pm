use 5.010; use strict; use warnings;

package MarpaX::Repa::Test;

use Marpa::R2;
use MarpaX::Repa::Lexer;
use MarpaX::Repa::Actions;

sub simple_lexer {
    my $self = shift;
    my %args = (@_);
    my $grammar = Marpa::R2::Grammar->new({
        action_object => 'MarpaX::Repa::Actions',
        start => 'text',
        default_action => 'do_what_I_mean',
        rules => [
            [ 'text'  => [ 'word' ] ],
        ],
        (
            map { $_ => $args{$_} } grep exists $args{$_},
            qw(start rules default_action),
        ),
    });
    $grammar->precompute;
    my $recognizer = Marpa::R2::Recognizer->new( { grammar => $grammar } );
    my $lexer = MarpaX::Repa::Lexer->new(
        tokens     => { word => 'test' },
        store      => 'scalar',
        %args,
        recognizer => $recognizer,
    );

    return ($lexer, $recognizer, $grammar);
}

sub recognize {
    my $self = shift;
    my %args = (@_);

    my $input = delete $args{'input'};
    my $io;
    unless ( ref $input ) {
        open $io, '<', \$input;
    } else {
        $io = $input;
    }

    my @res = $self->simple_lexer( %args );
    $res[0]->recognize( $io );
    return @res;
}

1;
