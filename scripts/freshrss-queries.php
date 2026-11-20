<?php
declare(strict_types=1);

require getenv('FRSS_CLI') . '/_cli.php';

$username = getenv('FRSS_USER');
cliInitUser($username);

$conf = FreshRSS_Context::userConf();

// De NixOS-module maakt de gebruiker aan zonder --no-default-feeds; haal de
// standaard FreshRSS-releases-feed weg zodat alleen de security-feeds overblijven.
$feedDAO = FreshRSS_Factory::createFeedDao();
foreach ($feedDAO->listFeeds() as $feed) {
	if ($feed->url() === 'https://github.com/FreshRSS/FreshRSS/releases.atom') {
		$feedDAO->deleteFeed($feed->id());
		echo "standaardfeed verwijderd: ", $feed->name(), "\n";
	}
}

$definitions = [
	'Mijn stack' => 'nginx OR openssl OR "linux kernel" OR nextcloud OR docker OR nixos',
	'Kritiek' => 'critical OR RCE OR "remote code execution" OR "actively exploited"',
	'NGINX' => 'nginx',
];

$queries = [];
foreach ($definitions as $name => $search) {
	$queries[] = (new FreshRSS_UserQuery([
		'name' => $name,
		'search' => $search,
	], FreshRSS_Context::categories(), FreshRSS_Context::labels()))->toArray();
}
$conf->queries = $queries;
$conf->save();

echo "streams: ", count($queries), "\n";
echo "default_state: ", $conf->default_state, " (2 = alleen ongelezen)\n";
