<script>
import { GlIcon, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { timeTilRun } from '../../utils';
import {
  PARTIAL_CLEANUP_CONTINUE_MESSAGE,
  CLEANUP_STATUS_SCHEDULED,
  CLEANUP_STATUS_ONGOING,
  CLEANUP_STATUS_UNFINISHED,
  UNFINISHED_STATUS,
  UNSCHEDULED_STATUS,
  SCHEDULED_STATUS,
  ONGOING_STATUS,
} from '../../constants/index';

export default {
  name: 'CleanupStatus',
  components: {
    GlIcon,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  props: {
    status: {
      type: String,
      required: true,
      validator(value) {
        return [UNFINISHED_STATUS, UNSCHEDULED_STATUS, SCHEDULED_STATUS, ONGOING_STATUS].includes(
          value,
        );
      },
    },
    expirationPolicy: {
      type: Object,
      default: () => ({}),
      required: false,
    },
  },
  i18n: {
    CLEANUP_STATUS_SCHEDULED,
    CLEANUP_STATUS_ONGOING,
    CLEANUP_STATUS_UNFINISHED,
    PARTIAL_CLEANUP_CONTINUE_MESSAGE,
  },
  computed: {
    showStatus() {
      return this.status !== UNSCHEDULED_STATUS;
    },
    failedDelete() {
      return this.status === UNFINISHED_STATUS;
    },
    statusText() {
      return this.$options.i18n[`CLEANUP_STATUS_${this.status}`];
    },
    calculatedTimeTilNextRun() {
      return timeTilRun(this.expirationPolicy?.next_run);
    },
  },
  statusPopoverOptions: {
    triggers: 'hover',
    placement: 'top',
  },
  cleanupPolicyHelpPage: helpPagePath(
    'user/packages/container_registry/reduce_container_registry_storage.html',
    { anchor: 'how-the-cleanup-policy-works' },
  ),
};
</script>

<template>
  <div
    v-if="showStatus"
    id="status-popover-container"
    class="gl-display-inline-flex gl-align-items-center"
  >
    <div class="gl-display-inline-flex gl-align-items-center">
      <gl-icon name="expire" data-testid="main-icon" />
    </div>
    <span class="gl-mx-2">
      {{ statusText }}
    </span>
    <gl-icon
      v-if="failedDelete"
      id="status-info"
      :size="14"
      class="gl-text-gray-500"
      data-testid="extra-info"
      name="information-o"
    />
    <gl-popover
      target="status-info"
      container="status-popover-container"
      v-bind="$options.statusPopoverOptions"
    >
      <template #title>
        {{ $options.i18n.CLEANUP_STATUS_UNFINISHED }}
      </template>
      <gl-sprintf :message="$options.i18n.PARTIAL_CLEANUP_CONTINUE_MESSAGE">
        <template #time>{{ calculatedTimeTilNextRun }}</template
        ><template #link="{ content }"
          ><gl-link :href="$options.cleanupPolicyHelpPage" class="gl-font-sm" target="_blank">{{
            content
          }}</gl-link></template
        >
      </gl-sprintf>
    </gl-popover>
  </div>
</template>
