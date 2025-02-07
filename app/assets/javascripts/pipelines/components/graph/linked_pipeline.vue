<script>
import {
  GlBadge,
  GlButton,
  GlLink,
  GlLoadingIcon,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { __, sprintf } from '~/locale';
import CancelPipelineMutation from '~/pipelines/graphql/mutations/cancel_pipeline.mutation.graphql';
import RetryPipelineMutation from '~/pipelines/graphql/mutations/retry_pipeline.mutation.graphql';
import CiStatus from '~/vue_shared/components/ci_icon.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { PIPELINE_GRAPHQL_TYPE } from '../../constants';
import { reportToSentry } from '../../utils';
import { ACTION_FAILURE, DOWNSTREAM, UPSTREAM } from './constants';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    CiStatus,
    GlBadge,
    GlButton,
    GlLink,
    GlLoadingIcon,
    GlTooltip,
  },
  styles: {
    actionSizeClasses: ['gl-h-7 gl-w-7'],
    flatLeftBorder: ['gl-rounded-bottom-left-none!', 'gl-rounded-top-left-none!'],
    flatRightBorder: ['gl-rounded-bottom-right-none!', 'gl-rounded-top-right-none!'],
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    columnTitle: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    pipeline: {
      type: Object,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasActionTooltip: false,
      isActionLoading: false,
    };
  },
  computed: {
    action() {
      if (this.glFeatures?.downstreamRetryAction && this.isDownstream) {
        if (this.isCancelable) {
          return {
            icon: 'cancel',
            method: this.cancelPipeline,
            ariaLabel: __('Cancel downstream pipeline'),
          };
        } else if (this.isRetryable) {
          return {
            icon: 'retry',
            method: this.retryPipeline,
            ariaLabel: __('Retry downstream pipeline'),
          };
        }
      }

      return {};
    },
    buttonBorderClasses() {
      return this.isUpstream
        ? ['gl-border-r-0!', ...this.$options.styles.flatRightBorder]
        : ['gl-border-l-0!', ...this.$options.styles.flatLeftBorder];
    },
    buttonId() {
      return `js-linked-pipeline-${this.pipeline.id}`;
    },
    cardClasses() {
      return this.isDownstream
        ? this.$options.styles.flatRightBorder
        : this.$options.styles.flatLeftBorder;
    },
    expandedIcon() {
      if (this.isUpstream) {
        return this.expanded ? 'angle-right' : 'angle-left';
      }
      return this.expanded ? 'angle-left' : 'angle-right';
    },
    childPipeline() {
      return this.isDownstream && this.isSameProject;
    },
    downstreamTitle() {
      return this.childPipeline ? this.sourceJobName : this.pipeline.project.name;
    },
    flexDirection() {
      return this.isUpstream ? 'gl-flex-direction-row-reverse' : 'gl-flex-direction-row';
    },
    graphqlPipelineId() {
      return convertToGraphQLId(PIPELINE_GRAPHQL_TYPE, this.pipeline.id);
    },
    hasUpdatePipelinePermissions() {
      return Boolean(this.pipeline?.userPermissions?.updatePipeline);
    },
    isCancelable() {
      return Boolean(this.pipeline?.cancelable && this.hasUpdatePipelinePermissions);
    },
    isDownstream() {
      return this.type === DOWNSTREAM;
    },
    isRetryable() {
      return Boolean(this.pipeline?.retryable && this.hasUpdatePipelinePermissions);
    },
    isSameProject() {
      return !this.pipeline.multiproject;
    },
    isUpstream() {
      return this.type === UPSTREAM;
    },
    label() {
      if (this.parentPipeline) {
        return __('Parent');
      } else if (this.childPipeline) {
        return __('Child');
      }
      return __('Multi-project');
    },
    parentPipeline() {
      return this.isUpstream && this.isSameProject;
    },
    pipelineIsLoading() {
      return Boolean(this.isLoading || this.pipeline.isLoading);
    },
    pipelineStatus() {
      return this.pipeline.status;
    },
    projectName() {
      return this.pipeline.project.name;
    },
    showAction() {
      return Boolean(this.action?.method && this.action?.icon && this.action?.ariaLabel);
    },
    showCardTooltip() {
      return !this.hasActionTooltip;
    },
    sourceJobName() {
      return this.pipeline.sourceJob?.name ?? '';
    },
    sourceJobInfo() {
      return this.isDownstream ? sprintf(__('Created by %{job}'), { job: this.sourceJobName }) : '';
    },
    cardTooltipText() {
      return `${this.downstreamTitle} #${this.pipeline.id} - ${this.pipelineStatus.label} -
      ${this.sourceJobInfo}`;
    },
  },
  errorCaptured(err, _vm, info) {
    reportToSentry('linked_pipeline', `error: ${err}, info: ${info}`);
  },
  methods: {
    cancelPipeline() {
      this.executePipelineAction(CancelPipelineMutation);
    },
    async executePipelineAction(mutation) {
      try {
        this.isActionLoading = true;

        await this.$apollo.mutate({
          mutation,
          variables: {
            id: this.graphqlPipelineId,
          },
        });
        this.$emit('refreshPipelineGraph');
      } catch {
        this.$emit('error', { type: ACTION_FAILURE });
      } finally {
        this.isActionLoading = false;
      }
    },
    hideTooltips() {
      this.$root.$emit(BV_HIDE_TOOLTIP);
    },
    onClickLinkedPipeline() {
      this.hideTooltips();
      this.$emit('pipelineClicked', this.$refs.linkedPipeline);
      this.$emit('pipelineExpandToggle', this.sourceJobName, !this.expanded);
    },
    onDownstreamHovered() {
      this.$emit('downstreamHovered', this.sourceJobName);
    },
    onDownstreamHoverLeave() {
      this.$emit('downstreamHovered', '');
    },
    retryPipeline() {
      this.executePipelineAction(RetryPipelineMutation);
    },
    setActionTooltip(flag) {
      this.hasActionTooltip = flag;
    },
  },
};
</script>

<template>
  <div
    ref="linkedPipeline"
    class="gl-h-full gl-display-flex!"
    :class="flexDirection"
    data-qa-selector="linked_pipeline_container"
    @mouseover="onDownstreamHovered"
    @mouseleave="onDownstreamHoverLeave"
  >
    <gl-tooltip v-if="showCardTooltip" :target="() => $refs.linkedPipeline">
      {{ cardTooltipText }}
    </gl-tooltip>
    <div class="gl-bg-white gl-border gl-p-3 gl-rounded-lg gl-w-full" :class="cardClasses">
      <div class="gl-display-flex gl-gap-x-3">
        <ci-status v-if="!pipelineIsLoading" :status="pipelineStatus" :size="24" css-classes="" />
        <div v-else class="gl-pr-3"><gl-loading-icon size="sm" inline /></div>
        <div
          class="gl-display-flex gl-downstream-pipeline-job-width gl-flex-direction-column gl-line-height-normal"
        >
          <span class="gl-text-truncate" data-testid="downstream-title">
            {{ downstreamTitle }}
          </span>
          <div class="gl-text-truncate">
            <gl-link
              class="gl-text-blue-500! gl-font-sm"
              :href="pipeline.path"
              data-testid="pipelineLink"
              >#{{ pipeline.id }}</gl-link
            >
          </div>
        </div>
        <gl-button
          v-if="showAction"
          v-gl-tooltip
          :title="action.ariaLabel"
          :loading="isActionLoading"
          :icon="action.icon"
          class="gl-rounded-full!"
          :class="$options.styles.actionSizeClasses"
          :aria-label="action.ariaLabel"
          @click="action.method"
          @mouseover="setActionTooltip(true)"
          @mouseout="setActionTooltip(false)"
        />
        <div v-else :class="$options.styles.actionSizeClasses"></div>
      </div>
      <div class="gl-pt-2">
        <gl-badge size="sm" variant="info" data-testid="downstream-pipeline-label">
          {{ label }}
        </gl-badge>
      </div>
    </div>
    <div class="gl-display-flex">
      <gl-button
        :id="buttonId"
        class="gl-border! gl-shadow-none! gl-rounded-lg!"
        :class="[`js-pipeline-expand-${pipeline.id}`, buttonBorderClasses]"
        :icon="expandedIcon"
        :aria-label="__('Expand pipeline')"
        data-testid="expand-pipeline-button"
        data-qa-selector="expand_linked_pipeline_button"
        @click="onClickLinkedPipeline"
      />
    </div>
  </div>
</template>
