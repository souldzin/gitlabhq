<script>
import {
  GlIcon,
  GlBadge,
  GlButton,
  GlIntersectionObserver,
  GlTooltipDirective,
  GlSafeHtmlDirective as SafeHtml,
} from '@gitlab/ui';
import { __ } from '~/locale';
import { IssuableStates } from '~/vue_shared/issuable/list/constants';

export default {
  i18n: {
    editTitleAndDescription: __('Edit title and description'),
  },
  components: {
    GlIcon,
    GlBadge,
    GlButton,
    GlIntersectionObserver,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  props: {
    issuable: {
      type: Object,
      required: true,
    },
    statusBadgeClass: {
      type: String,
      required: true,
    },
    statusIcon: {
      type: String,
      required: true,
    },
    enableEdit: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      stickyTitleVisible: false,
    };
  },
  computed: {
    badgeVariant() {
      return this.issuable.state === IssuableStates.Opened ? 'success' : 'info';
    },
  },
  methods: {
    handleTitleAppear() {
      this.stickyTitleVisible = false;
    },
    handleTitleDisappear() {
      this.stickyTitleVisible = true;
    },
  },
};
</script>

<template>
  <div>
    <div class="title-container">
      <h1
        v-safe-html="issuable.titleHtml || issuable.title"
        class="title qa-title"
        dir="auto"
        data-testid="title"
      ></h1>
      <gl-button
        v-if="enableEdit"
        v-gl-tooltip.bottom
        :title="$options.i18n.editTitleAndDescription"
        :aria-label="$options.i18n.editTitleAndDescription"
        icon="pencil"
        class="btn-edit js-issuable-edit qa-edit-button"
        @click="$emit('edit-issuable', $event)"
      />
    </div>
    <gl-intersection-observer @appear="handleTitleAppear" @disappear="handleTitleDisappear">
      <transition name="issuable-header-slide">
        <div
          v-if="stickyTitleVisible"
          class="issue-sticky-header gl-fixed gl-z-index-3 gl-bg-white gl-border-1 gl-border-b-solid gl-border-b-gray-100 gl-py-3"
          data-testid="header"
        >
          <div
            class="issue-sticky-header-text gl-display-flex gl-align-items-center gl-mx-auto gl-px-5"
          >
            <gl-badge
              class="gl-white-space-nowrap gl-mr-3"
              :class="statusBadgeClass"
              :variant="badgeVariant"
            >
              <gl-icon v-if="statusIcon" class="gl-sm-display-none" :name="statusIcon" />
              <span class="gl-display-none gl-sm-display-block">
                <slot name="status-badge"></slot>
              </span>
            </gl-badge>
            <p
              class="gl-font-weight-bold gl-overflow-hidden gl-white-space-nowrap gl-text-overflow-ellipsis gl-my-0"
              :title="issuable.title"
            >
              {{ issuable.title }}
            </p>
          </div>
        </div>
      </transition>
    </gl-intersection-observer>
  </div>
</template>
