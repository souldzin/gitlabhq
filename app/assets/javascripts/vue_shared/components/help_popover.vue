<script>
import { GlButton, GlPopover, GlSafeHtmlDirective } from '@gitlab/ui';

/**
 * Render a button with a question mark icon
 * On hover shows a popover. The popover will be dismissed on mouseleave
 */
export default {
  name: 'HelpPopover',
  components: {
    GlButton,
    GlPopover,
  },
  directives: {
    SafeHtml: GlSafeHtmlDirective,
  },
  props: {
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  methods: {
    targetFn() {
      return this.$refs.popoverTrigger?.$el;
    },
  },
};
</script>
<template>
  <span>
    <gl-button ref="popoverTrigger" variant="link" icon="question-o" :aria-label="__('Help')" />
    <gl-popover :target="targetFn" v-bind="options">
      <template v-if="options.title" #title>
        <span v-safe-html="options.title"></span>
      </template>
      <template #default>
        <div v-safe-html="options.content"></div>
      </template>
      <template v-for="slot in Object.keys($slots)" #[slot]>
        <slot :name="slot"></slot>
      </template>
    </gl-popover>
  </span>
</template>
