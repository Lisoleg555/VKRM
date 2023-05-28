/* ------------------------------------------------------------------------- *
 * Copyright 2002-2023, OpenNebula Project, OpenNebula Systems               *
 *                                                                           *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may   *
 * not use this file except in compliance with the License. You may obtain   *
 * a copy of the License at                                                  *
 *                                                                           *
 * http://www.apache.org/licenses/LICENSE-2.0                                *
 *                                                                           *
 * Unless required by applicable law or agreed to in writing, software       *
 * distributed under the License is distributed on an "AS IS" BASIS,         *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  *
 * See the License for the specific language governing permissions and       *
 * limitations under the License.                                            *
 * ------------------------------------------------------------------------- */
import BasicConfiguration, {
  STEP_ID as BASIC_ID,
} from 'client/components/Forms/MarketplaceApp/ExportForm/Steps/BasicConfiguration'
import DatastoresTable, {
  STEP_ID as DATASTORE_ID,
} from 'client/components/Forms/MarketplaceApp/ExportForm/Steps/DatastoresTable'
import DockerHubTagsTable, {
  STEP_ID as TAG_ID,
} from 'client/components/Forms/MarketplaceApp/ExportForm/Steps/DockerHubTagsTable'
import { createSteps } from 'client/utils'

const Steps = createSteps(
  (app) => {
    const isDockerImage = String(app?.MARKETPLACE).toLowerCase() === 'dockerhub'

    return [
      BasicConfiguration,
      DatastoresTable,
      isDockerImage && DockerHubTagsTable,
    ].filter(Boolean)
  },
  {
    transformInitialValue: (app, schema) =>
      schema.cast({}, { context: { app } }),
    transformBeforeSubmit: (formData) => {
      const {
        [BASIC_ID]: configuration,
        [DATASTORE_ID]: [datastore] = [],
        [TAG_ID]: [tag] = [],
      } = formData

      return {
        datastore: datastore?.ID,
        tag: tag?.name,
        ...configuration,
      }
    },
  }
)

export default Steps
