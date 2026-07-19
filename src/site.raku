# Site configuration for the Raku++ spec generator.
# This file is EVAL'd by build.raku and must evaluate to a Hash.
{
    title      => 'Raku++ Specification',
    tagline    => 'How Raku++ behaves — every feature explained, with runnable, verified examples.',
    engine     => 'https://raku.online/embed.js',
    playground => 'https://raku.online/',
    repo       => 'https://github.com/ash/raku-spec',

    # Order and display titles for the categories under src/pages/.
    categories => [
        { slug => 'literals',  title => 'Literals'  },
        { slug => 'operators', title => 'Operators' },
    ],
}
