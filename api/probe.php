<?php
/* DaliCards DB probe - M0. Verifies the server can create + use its own tables.
 * Reads creds from config.php (NEVER committed, generated at deploy time).
 * GET /dalicards-api/probe.php  ->  JSON
 */
error_reporting(0);
header('Content-Type: application/json; charset=utf-8');

$out = array('ok' => false, 'php' => PHP_VERSION, 'pdo_mysql' => false, 'db' => null);

if (!file_exists(__DIR__ . '/config.php')) {
    $out['code'] = 'no_config';
    echo json_encode($out);
    exit;
}
require __DIR__ . '/config.php';

try {
    $pdo = new PDO("mysql:host=" . DC_HOST . ";charset=utf8mb4", DC_USER, DC_PASS, array(
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ));
    $out['pdo_mysql'] = true;

    $pdo->exec("USE " . DC_DB);
    $out['db'] = DC_DB;

    $pdo->exec("CREATE TABLE IF NOT EXISTS dc_probe (
        id INT AUTO_INCREMENT PRIMARY KEY,
        note VARCHAR(64) NOT NULL,
        at INT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $st = $pdo->prepare("INSERT INTO dc_probe (note, at) VALUES (?, ?)");
    $st->execute(array('m0', time()));

    $n = $pdo->query("SELECT COUNT(*) FROM dc_probe")->fetchColumn();
    $out['rows'] = intval($n);
    $out['server'] = $pdo->query("SELECT VERSION()")->fetchColumn();
    $out['ok'] = true;
} catch (Exception $e) {
    $out['error'] = $e->getMessage();
}

echo json_encode($out, JSON_UNESCAPED_SLASHES);
