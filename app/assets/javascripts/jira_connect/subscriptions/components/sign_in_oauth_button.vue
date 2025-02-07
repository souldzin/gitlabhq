<script>
import { mapActions, mapMutations } from 'vuex';
import { GlButton } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import {
  I18N_DEFAULT_SIGN_IN_BUTTON_TEXT,
  OAUTH_WINDOW_OPTIONS,
  PKCE_CODE_CHALLENGE_DIGEST_ALGORITHM,
} from '~/jira_connect/subscriptions/constants';
import { setUrlParams } from '~/lib/utils/url_utility';
import AccessorUtilities from '~/lib/utils/accessor';
import { createCodeVerifier, createCodeChallenge } from '../pkce';
import { SET_ACCESS_TOKEN } from '../store/mutation_types';

export default {
  components: {
    GlButton,
  },
  inject: ['oauthMetadata'],
  data() {
    return {
      token: null,
      loading: false,
      codeVerifier: null,
      canUseCrypto: AccessorUtilities.canUseCrypto(),
    };
  },
  created() {
    window.addEventListener('message', this.handleWindowMessage);
  },
  beforeDestroy() {
    window.removeEventListener('message', this.handleWindowMessage);
  },
  methods: {
    ...mapActions(['loadCurrentUser']),
    ...mapMutations({
      setAccessToken: SET_ACCESS_TOKEN,
    }),
    async startOAuthFlow() {
      this.loading = true;

      // Generate state necessary for PKCE OAuth flow
      this.codeVerifier = createCodeVerifier();
      const codeChallenge = await createCodeChallenge(this.codeVerifier);

      // Build the initial OAuth authorization URL
      const { oauth_authorize_url: oauthAuthorizeURL } = this.oauthMetadata;

      const oauthAuthorizeURLWithChallenge = setUrlParams(
        {
          code_challenge: codeChallenge,
          code_challenge_method: PKCE_CODE_CHALLENGE_DIGEST_ALGORITHM.short,
        },
        oauthAuthorizeURL,
      );

      window.open(
        oauthAuthorizeURLWithChallenge,
        this.$options.i18n.defaultButtonText,
        OAUTH_WINDOW_OPTIONS,
      );
    },
    async handleWindowMessage(event) {
      if (window.origin !== event.origin) {
        this.loading = false;
        return;
      }

      // Verify that OAuth state isn't altered.
      const state = event.data?.state;
      if (state !== this.oauthMetadata.state) {
        this.loading = false;
        this.handleError();
        return;
      }

      // Request access token and load the authenticated user.
      const code = event.data?.code;
      try {
        const accessToken = await this.getOAuthToken(code);
        await this.loadCurrentUser(accessToken);

        this.setAccessToken(accessToken);
        this.$emit('sign-in');
      } catch (e) {
        this.handleError();
      } finally {
        this.loading = false;
      }
    },
    handleError() {
      this.$emit('error');
    },
    async getOAuthToken(code) {
      const {
        oauth_token_payload: oauthTokenPayload,
        oauth_token_url: oauthTokenURL,
      } = this.oauthMetadata;
      const { data } = await axios.post(oauthTokenURL, {
        ...oauthTokenPayload,
        code,
        code_verifier: this.codeVerifier,
      });

      return data.access_token;
    },
  },
  i18n: {
    defaultButtonText: I18N_DEFAULT_SIGN_IN_BUTTON_TEXT,
  },
};
</script>
<template>
  <gl-button
    category="primary"
    variant="info"
    :loading="loading"
    :disabled="!canUseCrypto"
    @click="startOAuthFlow"
  >
    <slot>
      {{ $options.i18n.defaultButtonText }}
    </slot>
  </gl-button>
</template>
