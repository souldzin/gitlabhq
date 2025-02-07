<script>
import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { i18n } from '../constants';
import workItemQuery from '../graphql/work_item.query.graphql';
import workItemTitleSubscription from '../graphql/work_item_title.subscription.graphql';
import WorkItemActions from './work_item_actions.vue';
import WorkItemState from './work_item_state.vue';
import WorkItemTitle from './work_item_title.vue';

export default {
  i18n,
  components: {
    GlAlert,
    GlSkeletonLoader,
    WorkItemActions,
    WorkItemTitle,
    WorkItemState,
  },
  props: {
    workItemId: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      error: undefined,
      workItem: {},
    };
  },
  apollo: {
    workItem: {
      query: workItemQuery,
      variables() {
        return {
          id: this.workItemId,
        };
      },
      skip() {
        return !this.workItemId;
      },
      error() {
        this.error = this.$options.i18n.fetchError;
      },
      subscribeToMore: {
        document: workItemTitleSubscription,
        variables() {
          return {
            issuableId: this.workItemId,
          };
        },
      },
    },
  },
  computed: {
    workItemLoading() {
      return this.$apollo.queries.workItem.loading;
    },
    workItemType() {
      return this.workItem.workItemType?.name;
    },
    canUpdate() {
      return this.workItem?.userPermissions?.updateWorkItem;
    },
    canDelete() {
      return this.workItem?.userPermissions?.deleteWorkItem;
    },
  },
};
</script>

<template>
  <section>
    <gl-alert v-if="error" variant="danger" @dismiss="error = undefined">
      {{ error }}
    </gl-alert>

    <div v-if="workItemLoading" class="gl-max-w-26 gl-py-5">
      <gl-skeleton-loader :height="65" :width="240">
        <rect width="240" height="20" x="5" y="0" rx="4" />
        <rect width="100" height="20" x="5" y="45" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <div class="gl-display-flex">
        <work-item-title
          :work-item-id="workItem.id"
          :work-item-title="workItem.title"
          :work-item-type="workItemType"
          class="gl-mr-5"
          @error="error = $event"
          @updated="$emit('workItemUpdated')"
        />
        <work-item-actions
          :work-item-id="workItem.id"
          :can-delete="canDelete"
          class="gl-ml-auto gl-mt-5"
          @deleteWorkItem="$emit('deleteWorkItem')"
          @error="error = $event"
        />
      </div>
      <work-item-state
        :work-item="workItem"
        @error="error = $event"
        @updated="$emit('workItemUpdated')"
      />
    </template>
  </section>
</template>
