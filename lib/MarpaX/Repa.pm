use 5.010;
use strict;
use warnings;

package MarpaX::Repa;
our $VERSION = '0.04';

=head1 NAME

MarpaX::Repa - helps start with Marpa

=head1 SYNOPSIS

Shipped with distribution - F<examples/synopsis.pl>:

    use 5.010;
    use strict;
    use warnings;
    use lib 'lib/';

    use Marpa::R2;
    use MarpaX::Repa::Lexer;
    use MarpaX::Repa::Actions;

    my $grammar = Marpa::R2::Grammar->new( {
        action_object => 'MarpaX::Repa::Actions',
        default_action => 'do_scalar_or_list',
        start   => 'query',
        rules   => [
            {
                lhs => 'query', rhs => [qw(condition)],
                min => 1, separator => 'OP', proper => 1, keep => 1,
            },
            [ condition => [qw(word)] ],
            [ condition => [qw(quoted)] ],
            [ condition => [qw(OPEN-PAREN SPACE? query SPACE? CLOSE-PAREN)] ],
            [ condition => [qw(NOT condition)] ],

            [ 'SPACE?' => [] ],
            { lhs => 'SPACE?', rhs => [qw(SPACE)], action => 'do_ignore', },
        ],
    });
    $grammar->precompute;
    my $recognizer = Marpa::R2::Recognizer->new( { grammar => $grammar } );

    use Regexp::Common qw /delimited/;

    my $lexer = MyLexer->new(
        recognizer => $recognizer,
        tokens => {
            word          => { match => qr{\b\w+\b}, store => 'scalar' },
            'quoted'      => {
                match => qr[$RE{delimited}{-delim=>qq{\"}}],
                store => sub {
                    ${$_[1]} =~ s/^"//;
                    ${$_[1]} =~ s/"$//;
                    ${$_[1]} =~ s/\\([\\"])/$1/g;
                    return $_[1];
                },
            },
            OP            => {
                match => qr{\s+OR\s+|\s+},
                store => sub { ${$_[1]} =~ /\S/? \'|' : \'&' }
            },
            NOT           => { match => '!', store => sub {\'!'} },
            'OPEN-PAREN'  => { match => '(', store => 'undef' },
            'CLOSE-PAREN' => { match => ')', store => 'undef' },
            'SPACE'       => { match => qr{\s+}, store => 'undef' },
        },
        debug => 1,
    );

    $lexer->recognize(\*DATA);

    use Data::Dumper;
    print Dumper $recognizer->value;

    package MyLexer;
    use base 'MarpaX::Repa::Lexer';

    sub grow_buffer {
        my $self = shift;
        my $rv = $self->SUPER::grow_buffer( @_ );
        ${ $self->buffer } =~ s/[\r\n]+//g;
        return $rv;
    }

    package main;
    __DATA__
    hello !world OR "he hehe hee" ( foo OR !boo )

=head1 WARNING

This is experimental module in beta stage. Some API still may change,
but it's already very close to stability.

=head1 DESCRIPTION

This module helps you start with L<Marpa::R2> parser and simplifies lexing.

=head1 TUTORIAL

=head2 Where to start

Here is template you can start a new parser from
(shipped with distribution - F<examples/template.pl>):

    use strict; use warnings;

    use Marpa::R2;
    use MarpaX::Repa::Lexer;
    use MarpaX::Repa::Actions;

    my $grammar = Marpa::R2::Grammar->new( {
        action_object => 'MarpaX::Repa::Actions',
        start         => 'query',
        rules         => [
            [ query => [qw(something)] ],
        ],
    });
    $grammar->precompute;
    my $recognizer = Marpa::R2::Recognizer->new( { grammar => $grammar } );
    my $lexer = MarpaX::Repa::Lexer->new(
        recognizer => $recognizer,
        tokens => {},
        debug => 1,
    );

    $lexer->recognize(\*DATA);

    __DATA__
    hello !world "he hehe hee" ( foo OR boo )

It's a working program that prints the following output:

    Expect token(s): 'something'
    Buffer start: hello !world "he heh...
    Unknown token: 'something'
    Failed to parse: Problem in ...

First line says that at this moment parser expects 'something'.
It's going to look for it in the following text (second line).
Third line says that lexer doesn't know anything about 'something'.
It's not a surprise that parsing fails.

What can we do with 'something'? We either put it into grammar or
lexer. In above example it's pretty obvious that it's gonna be in
the grammar.

=head2 Put some grammar

    rules   => [
        # query is a sequence of conditions separated with OPs
        {
            lhs => 'query', rhs => [qw(condition)],
            min => 1, separator => 'OP', proper => 1, keep => 1,
        },
        # each condition can be one of the following
        [ condition => [qw(word)] ],
        [ condition => [qw(quoted)] ],
        [ condition => [qw(OPEN-PAREN SPACE? query SPACE? CLOSE-PAREN)] ],
        [ condition => [qw(NOT condition)] ],
    ],

Our program works and gives us helpful results:

    Expect token(s): 'word', 'quoted', 'OPEN-PAREN', 'NOT'
    Buffer start: hello !world OR "he ...
    Unknown token: 'word'
    ...

=head2 First token

    tokens => {
        word => qr{\w+},
    },

Ouput:

    Expect token(s): 'word', 'quoted', 'OPEN-PAREN', 'NOT'
    Buffer start: hello !world OR "he ...
    Token 'word' matched hello
    Unknown token: 'quoted'
    Unknown token: 'OPEN-PAREN'
    Unknown token: 'NOT'
    Expect token(s): 'OP'

Congrats! First token matched. More tokens:

    use Regexp::Common qw /delimited/;

    my $lexer = MarpaX::Repa::Lexer->new(
        recognizer => $recognizer,
        tokens => {
            word => qr{\b\w+\b},
            OP => qr{\s+|\s+OR\s+},
            NOT => '!',
            'OPEN-PAREN' => '(',
            'CLOSE-PAREN' => ')',
            'quoted' => qr[$RE{delimited}{-delim=>qq{\"}}],
        },
        debug => 1,
    );

=head2 Tokens matching empty string

You can not have such. In our example grammar we have 'SPACE?' that
is optional. You could try to use C<qr{\s*}>, but lexer would die
with an error. Instead use the following rules:

    rules   => [
        ...
        [ 'SPACE?' => [] ],
        [ 'SPACE?' => [qw(SPACE)] ],
    ],
    ...
    tokens => {
        ...
        'SPACE'       => qr{\s+},
    },

=head2 Lexer's ambiguity

This module uses marpa's alternative input model what allows you to
describe an ambiguous lexer, e.g. several tokens start at the same
position. This does not always give you multiple parse trees, but
allows you to start faster and keep improving tokens and grammar
to avoid unnecessary ambiguity cases.

=head2 Longest token match

Let's look at string "x OR y". It should match "word OP word",
but it matches "word OP word OP word" and it's not correct.
It happens because of how we defined OP token - C<qr{\s+|\s+OR\s+}>.
If we change it to C<qr{\s+OR\s+|\s+}> then we get correct result.

=head2 Input buffer

By default lexer reads data from the input stream in chunks into
a buffer and grow the buffer only when it's shorter than
C<min_buffer> bytes. By default it's 4kb. This is good for memory
consuption, but it can result in troubles when a terminal may be
larger than a buffer. For example consider a document with embedded
base64 encoded binary files. You can use several solutions to
workaround this problem.

Read everything into memory. Simplest way out. It's not default
value to avoid encouragement:

    my $lexer = MarpaX::Repa::Lexer->new(
        min_buffer => 0,
        ...
    );

Use larger buffer:

    my $lexer = MarpaX::Repa::Lexer->new(
        min_buffer => 10*1024*1024, # 10MB
        ...
    );

Use built in protection from such cases. When a token based on a
regular expression matches whole buffer and buffer still can grow
then lexer grows buffer and retries. This allows you to write a regular
expression that matches till end of token or end of input (C<$>).
Note that this may result in token incomplete match if input ends
right in the middle of it.

    tokens => {
        ...
        'text-paragraph' => qr{\w[\w\s]+?(?:\n\n|$)},
    },

Adjust grammar. In most cases you can split a long terminal into
multiple terminals with limitted length. For example:

    rules   => [
        ...
        { lhs => 'text', rhs => 'text-chunk', min => 1 },
    ],

=head2 Filtering input

Input can be filtered with subclassing grow_buffer method:

    package MyLexer;
    use base 'MarpaX::Repa::Lexer';

    sub grow_buffer {
        my $self = shift;
        my $rv = $self->SUPER::grow_buffer( @_ );
        ${ $self->buffer } =~ s/[\r\n]+//g;
        return $rv;
    }

=head2 Actions

Repa comes with set of actions to help you start by concentrating
on grammar. Start from <MarpaX::Repa::Actions/do_what_I_mean>:

    my $grammar = Marpa::R2::Grammar->new( {
        action_object  => 'MarpaX::Repa::Actions',
        default_action => 'do_what_I_mean',
        ...
    );

=head2 Token's values

Values of tokens are set to a hash by default:

    { token => 'a token name', value => 'matched value' }

You can change format per token or for all tokens using
'store' option, see L</SYNOPSIS> for examples and
L<MarpaX::Repa::Lexer> for full list.

=head2 What's next

Add more actions. Experiment. Enjoy.

=cut

=head1 AUTHOR

Ruslan Zakirov E<lt>Ruslan.Zakirov@gmail.comE<gt>

=head1 LICENSE

Under the same terms as perl itself.

=cut

1;