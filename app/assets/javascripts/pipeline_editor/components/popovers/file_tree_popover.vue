<script>
import { GlLink, GlPopover, GlOutsideDirective as Outside, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { FILE_TREE_POPOVER_DISMISSED_KEY } from '../../constants';

export default {
  name: 'PipelineEditorFileTreePopover',
  directives: { Outside },
  i18n: {
    description: s__(
      'pipelineEditorWalkthrough|You can use the file tree to view your pipeline configuration files. %{linkStart}Learn more%{linkEnd}',
    ),
  },
  components: {
    GlLink,
    GlPopover,
    GlSprintf,
  },
  inject: ['includesHelpPagePath'],
  data() {
    return {
      showPopover: false,
    };
  },
  mounted() {
    this.showPopover = localStorage.getItem(FILE_TREE_POPOVER_DISMISSED_KEY) !== 'true';
  },
  methods: {
    closePopover() {
      this.showPopover = false;
    },
    dismissPermanently() {
      this.closePopover();
      localStorage.setItem(FILE_TREE_POPOVER_DISMISSED_KEY, 'true');
    },
  },
};
</script>

<template>
  <gl-popover
    v-if="showPopover"
    show
    show-close-button
    target="file-tree-toggle"
    triggers="manual"
    placement="right"
    data-qa-selector="file_tree_popover"
    @close-button-clicked="dismissPermanently"
  >
    <div v-outside="closePopover" class="gl-font-base gl-mb-3">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="includesHelpPagePath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
  </gl-popover>
</template>
