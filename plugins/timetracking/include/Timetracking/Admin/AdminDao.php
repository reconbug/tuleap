<?php
/**
 * Copyright (c) Enalean, 2017 - 2018. All Rights Reserved.
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

namespace Tuleap\Timetracking\Admin;

use DataAccessObject;

class AdminDao extends DataAccessObject
{
    public function enableTimetrackingForTracker($tracker_id)
    {
        $tracker_id = $this->da->escapeInt($tracker_id);

        $sql = "REPLACE INTO plugin_timetracking_enabled_trackers
                VALUES ($tracker_id)";

        return $this->update($sql);
    }

    public function disableTimetrackingForTracker($tracker_id)
    {
        $tracker_id = $this->da->escapeInt($tracker_id);

        $sql = "DELETE FROM plugin_timetracking_enabled_trackers
                WHERE tracker_id = $tracker_id";

        return $this->update($sql);
    }

    public function isTimetrackingEnabledForTracker($tracker_id)
    {
        $tracker_id = $this->da->escapeInt($tracker_id);

        $sql = "SELECT NULL
                FROM plugin_timetracking_enabled_trackers
                WHERE tracker_id = $tracker_id";

        $this->retrieveFirstRow($sql);
        return $this->foundRows() > 0;
    }
}
