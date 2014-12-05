<?php
/**
 * Copyright (c) Enalean, 2014. All Rights Reserved.
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
 * along with Tuleap; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

namespace Tuleap\AgileDashboard\REST\v1;

use Tracker_Artifact_PriorityDao;
use Tracker_Artifact_Exception_CannotRankWithMyself;
use Tracker_FormElement_Field_ArtifactLink;
use Tracker_Artifact;
use PFUser;
use Tracker_FormElementFactory;

class ArtifactLinkUpdater {

    /** @var Tracker_FormElementFactory */
    private $form_element_factory;

    public function __construct(Tracker_FormElementFactory $form_element_factory) {
        $this->form_element_factory = $form_element_factory;
    }


    public function update(array $new_backlogitems_ids, Tracker_Artifact $artifact, PFUser $current_user, IFilterValidElementsToUnkink $filter) {
        $artlink_fields        = $this->form_element_factory->getUsedArtifactLinkFields($artifact->getTracker());

        if (! count($artlink_fields)) {
            return;
        }

        $fields_data = $this->getFieldsDataForNewChangeset(
            $artlink_fields[0],
            $artifact,
            $current_user,
            $filter,
            $new_backlogitems_ids
        );

        $this->unlinkAndLinkElements($artifact, $fields_data, $current_user, $new_backlogitems_ids);
    }

    private function getFieldsDataForNewChangeset(
        Tracker_FormElement_Field_ArtifactLink $artlink_field,
        Tracker_Artifact $artifact,
        PFUser $current_user,
        IFilterValidElementsToUnkink $filter,
        array $new_submilestones_ids
    ) {
        $elements_already_linked = $this->getElementsAlreadyLinkedToMilestone($artifact, $current_user);

        $backlogitems_to_be_unlinked = $this->getAllSubmilestonesToBeRemoved(
            $current_user,
            $filter,
            $elements_already_linked,
            $new_submilestones_ids
        );

        $submilestones_to_be_linked = $this->getElementsToLink(
            $elements_already_linked,
            $new_submilestones_ids
        );

        return $this->formatFieldDatas($artlink_field, $submilestones_to_be_linked, $backlogitems_to_be_unlinked);
    }

    private function getAllSubmilestonesToBeRemoved(PFUser $user, IFilterValidElementsToUnkink $filter, array $elements_already_linked, array $new_ids) {
        $artifacts_to_be_removed = $this->getAllLinkedArtifactsThatShouldBeRemoved($elements_already_linked, $new_ids);

        return $filter->filter($user, $artifacts_to_be_removed);
    }

    private function getAllLinkedArtifactsThatShouldBeRemoved(array $elements_already_linked, array $new_ids) {
        return array_diff($elements_already_linked, $new_ids);
    }

    public function getElementsToLink(array $elements_already_linked, array $new_submilestones_ids) {
        return array_diff($new_submilestones_ids, $elements_already_linked);
    }

    public function unlinkAndLinkElements(Tracker_Artifact $artifact, array $fields_data, PFUser $current_user, array $linked_artifact_ids) {
        try {
            $artifact->createNewChangeset($fields_data, '', $current_user, '');
        } catch (Tracker_NoChangeException $exception) {
            //Do nothing. Just need to reorder the items
        } catch (Exception $exception) {
            return false;
        }

        $this->setOrder($linked_artifact_ids);
    }

    public function getElementsAlreadyLinkedToMilestone(Tracker_Artifact $artifact, PFUser $user) {
        return array_map(
            function (Tracker_Artifact $artifact) {
                return $artifact->getId();
            },
            $artifact->getLinkedArtifacts($user)
        );
    }

    public function setOrder(array $linked_artifact_ids) {
        $dao         = new Tracker_Artifact_PriorityDao();
        $predecessor = null;

        foreach ($linked_artifact_ids as $linked_artifact_id) {
            if (isset($predecessor)) {
                try {
                    $dao->moveArtifactAfter($linked_artifact_id, $predecessor);
                } catch (Tracker_Artifact_Exception_CannotRankWithMyself $exception) {
                    throw new ItemListedTwiceException($linked_artifact_id);
                }
            }
            $predecessor = $linked_artifact_id;
        }
    }

    public function formatFieldDatas(Tracker_FormElement_Field_ArtifactLink $artifactlink_field, array $elements_to_be_linked, array $elements_to_be_unlinked) {
        $field_datas = array();

        $field_datas[$artifactlink_field->getId()]['new_values']     = $this->formatLinkedElementForNewChangeset($elements_to_be_linked);
        $field_datas[$artifactlink_field->getId()]['removed_values'] = $this->formatElementsToBeUnlinkedForNewChangeset($elements_to_be_unlinked);

        return $field_datas;
    }

    private function formatLinkedElementForNewChangeset(array $linked_elements) {
        return implode(',', $linked_elements);
    }

    private function formatElementsToBeUnlinkedForNewChangeset(array $elements_to_be_unlinked) {
        $formated_elements = array();

        foreach ($elements_to_be_unlinked as $element_to_be_unlinked) {
            $formated_elements[$element_to_be_unlinked] = 1;
        }

        return $formated_elements;
    }
}