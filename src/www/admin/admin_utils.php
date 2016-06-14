<?php


function site_admin_header($params) {
    GLOBAL $HTML, $Language;
	global $feedback;
	$HTML->header($params);
	echo html_feedback_top($feedback);
}

function site_admin_footer($vals=0) {
	GLOBAL $HTML;
	echo html_feedback_bottom($GLOBALS['feedback']);
	$HTML->footer(array());
}

function site_admin_warnings() {
    $forgeupgrade_config = new ForgeUpgradeConfig(new System_Command());
    $forgeupgrade_config->loadDefaults();
    if (! $forgeupgrade_config->isSystemUpToDate()) {
        return '<div class="alert alert-error">'.$GLOBALS['Language']->getText('admin_main', 'forgeupgrade').'</div>';
    }
}
