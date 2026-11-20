<?php
declare(strict_types=1);

require getenv('FRSS_CLI') . '/_cli.php';
cliInitUser(getenv('FRSS_USER'));

$conf = FreshRSS_Context::userConf();

// Alles wat NIET over deze onderwerpen gaat, automatisch als gelezen markeren.
// Zo blijft de ongelezen-stroom relevant; de artikelen zelf blijven bestaan.
$filterSearch = '!(nginx OR php OR apache OR nixos OR "linux kernel" OR linux-kernel)';
$conf->_filtersAction('read', [$filterSearch]);

// Stream "Relevant" met precies deze onderwerpen, alleen ongelezen.
$relevantSearch = 'nginx OR php OR apache OR nixos OR "linux kernel" OR linux-kernel';
$queries = $conf->queries;
$updated = false;
foreach ($queries as $key => $query) {
	if (($query['name'] ?? '') === 'Relevant') {
		$queries[$key] = (new FreshRSS_UserQuery([
			'name' => 'Relevant',
			'search' => $relevantSearch,
			'state' => FreshRSS_Entry::STATE_NOT_READ,
		], FreshRSS_Context::categories(), FreshRSS_Context::labels()))->toArray();
		$updated = true;
	}
}
if (!$updated) {
	$queries[] = (new FreshRSS_UserQuery([
		'name' => 'Relevant',
		'search' => $relevantSearch,
		'state' => FreshRSS_Entry::STATE_NOT_READ,
	], FreshRSS_Context::categories(), FreshRSS_Context::labels()))->toArray();
}
$conf->queries = array_values($queries);
$conf->save();

echo "filter: ", $filterSearch, "\n";
echo "stream Relevant: ", $relevantSearch, "\n";

// Bestaande ongelezen berichten die niet relevant zijn, nu al als gelezen zetten.
if (getenv('RETRO') === '1') {
	$entryDAO = FreshRSS_Factory::createEntryDao();
	$search = new FreshRSS_BooleanSearch($filterSearch);
	$ids = [];
	foreach ($entryDAO->listWhere('a', 0, FreshRSS_Entry::STATE_NOT_READ, $search, limit: 5000) as $entry) {
		$ids[] = $entry->id();
	}
	$changed = $ids === [] ? 0 : $entryDAO->markRead($ids, true);
	echo "bestaande onrelevante ongelezen -> gelezen: ", $changed, "\n";
}
