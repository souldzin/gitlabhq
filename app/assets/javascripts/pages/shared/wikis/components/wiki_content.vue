<script>
import { GlSkeletonLoader, GlSafeHtmlDirective, GlAlert } from '@gitlab/ui';
import createFlash from '~/flash';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { renderGFM } from '../render_gfm_facade';

export default {
  components: {
    GlSkeletonLoader,
    GlAlert,
  },
  directives: {
    SafeHtml: GlSafeHtmlDirective,
  },
  props: {
    getWikiContentUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isLoadingContent: false,
      loadingContentFailed: false,
      content: null,
    };
  },
  mounted() {
    this.loadWikiContent();
  },
  methods: {
    async loadWikiContent() {
      this.loadingContentFailed = false;
      this.isLoadingContent = true;

      try {
        const {
          data: { content },
        } = await axios.get(this.getWikiContentUrl, { params: { render_html: true } });
        this.content = content;

        this.$nextTick()
          .then(() => {
            renderGFM(this.$refs.content);
          })
          .catch(() =>
            createFlash({
              message: this.$options.i18n.renderingContentFailed,
            }),
          );
      } catch (e) {
        this.loadingContentFailed = true;
      } finally {
        this.isLoadingContent = false;
      }
    },
  },
  i18n: {
    loadingContentFailed: __(
      'The content for this wiki page failed to load. To fix this error, reload the page.',
    ),
    retryLoadingContent: __('Retry'),
    renderingContentFailed: __('The content for this wiki page failed to render.'),
  },
};
</script>
<template>
  <gl-skeleton-loader v-if="isLoadingContent" :width="830" :height="113">
    <rect width="540" height="16" rx="4" />
    <rect y="49" width="701" height="16" rx="4" />
    <rect y="24" width="830" height="16" rx="4" />
    <rect y="73" width="540" height="16" rx="4" />
  </gl-skeleton-loader>
  <gl-alert
    v-else-if="loadingContentFailed"
    :dismissible="false"
    variant="danger"
    :primary-button-text="$options.i18n.retryLoadingContent"
    @primaryAction="loadWikiContent"
  >
    {{ $options.i18n.loadingContentFailed }}
  </gl-alert>
  <div
    v-else-if="!loadingContentFailed && !isLoadingContent"
    ref="content"
    data-qa-selector="wiki_page_content"
    data-testid="wiki_page_content"
    class="js-wiki-page-content md"
    v-html="content /* eslint-disable-line vue/no-v-html */"
  ></div>
</template>
