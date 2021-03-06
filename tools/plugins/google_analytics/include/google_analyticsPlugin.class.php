<?php
/*
 * Copyright (c) Enalean, 2011 - 2018. All Rights Reserved.
 * Copyright (c) Xerox, 2010. All Rights Reserved.
 *
 * Originally written by Nicolas Terray, 2010. Xerox Codendi Team.
 *
 * This file is a part of Tuleap.
 *
 * Tuleap is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Tuleap is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Tuleap. If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Google_AnalyticsPlugin
 */
class Google_AnalyticsPlugin extends Plugin {

    public function __construct($id) {
        parent::__construct($id);
        $this->addHook(Event::JAVASCRIPT_FOOTER, 'getAnalyticsCode', false);
    }

    function getPluginInfo() {
        if (!is_a($this->pluginInfo, 'Google_AnalyticsPluginInfo')) {
            require_once('Google_AnalyticsPluginInfo.class.php');
            $this->pluginInfo = new Google_AnalyticsPluginInfo($this);
        }
        return $this->pluginInfo;
    }

    function getAnalyticsCode() {
        $ga_code = <<<EOS
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', '%s']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
EOS;
        $ga_id = $this->getPluginInfo()->getPropVal('google_analytics_id');
        $ga_code = sprintf($ga_code, $ga_id);
        echo $ga_code;
    }
}
