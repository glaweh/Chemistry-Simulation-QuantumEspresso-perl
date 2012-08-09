use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Chemistry::Simulation::QuantumEspresso',
    license             => 'gpl',
    dist_author         => q{Henning Glawe <glawe@web.de>},
    dist_version_from   => 'lib/Chemistry/Simulation/QuantumEspresso/pw/out.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Chemistry-Simulation-QuantumEspresso-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
