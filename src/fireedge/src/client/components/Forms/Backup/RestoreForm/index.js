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
} from 'client/components/Forms/Backup/RestoreForm/Steps/BasicConfiguration'
import DatastoresTable, {
  STEP_ID as DATASTORE_ID,
} from 'client/components/Forms/Backup/RestoreForm/Steps/DatastoresTable'
import { createSteps } from 'client/utils'

const Steps = createSteps([BasicConfiguration, DatastoresTable], {
  transformInitialValue: (increments, schema) => {
    const castedValuesBasic = schema.cast(
      { [BASIC_ID]: { increments } },
      { stripUnknown: true }
    )

    const castedValuesDatastore = schema.cast(
      { [DATASTORE_ID]: {} },
      { stripUnknown: true }
    )

    return {
      [BASIC_ID]: castedValuesBasic[BASIC_ID],
      [DATASTORE_ID]: castedValuesDatastore[DATASTORE_ID],
    }
  },
  transformBeforeSubmit: (formData) => {
    const { [BASIC_ID]: configuration, [DATASTORE_ID]: [datastore] = [] } =
      formData

    return {
      datastore: datastore?.ID,
      ...configuration,
    }
  },
})

export default Steps
