<script>
import { GlAlert, GlFormInputGroup, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';
import CodeBlock from '~/vue_shared/components/code_block.vue';
import { generateAgentRegistrationCommand } from '../clusters_util';
import { I18N_AGENT_TOKEN } from '../constants';

export default {
  i18n: I18N_AGENT_TOKEN,
  advancedInstallPath: helpPagePath('user/clusters/agent/install/index', {
    anchor: 'advanced-installation-method',
  }),
  components: {
    GlAlert,
    CodeBlock,
    GlFormInputGroup,
    GlLink,
    GlSprintf,
    ModalCopyButton,
  },
  inject: ['kasAddress'],
  props: {
    agentToken: {
      required: true,
      type: String,
    },
    modalId: {
      required: true,
      type: String,
    },
  },
  computed: {
    agentRegistrationCommand() {
      return generateAgentRegistrationCommand(this.agentToken, this.kasAddress);
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-3">{{ $options.i18n.tokenLabel }}</p>

    <p>
      <gl-form-input-group readonly :value="agentToken" :select-on-click="true">
        <template #append>
          <modal-copy-button
            :text="agentToken"
            :title="$options.i18n.copyToken"
            :modal-id="modalId"
          />
        </template>
      </gl-form-input-group>
    </p>

    <p>
      {{ $options.i18n.tokenSubtitle }}
    </p>

    <gl-alert :dismissible="false" variant="warning" class="gl-mb-5">
      {{ $options.i18n.tokenSingleUseWarningTitle }}
    </gl-alert>

    <p>
      <strong>{{ $options.i18n.basicInstallTitle }}</strong>
    </p>

    <p>
      {{ $options.i18n.basicInstallBody }}
    </p>

    <p class="gl-display-flex gl-align-items-flex-start">
      <code-block class="gl-w-full" :code="agentRegistrationCommand" />
      <modal-copy-button
        :title="$options.i18n.copyCommand"
        :text="agentRegistrationCommand"
        :modal-id="modalId"
      />
    </p>

    <p>
      <strong>{{ $options.i18n.advancedInstallTitle }}</strong>
    </p>

    <p>
      <gl-sprintf :message="$options.i18n.advancedInstallBody">
        <template #link="{ content }">
          <gl-link :href="$options.advancedInstallPath" target="_blank"> {{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
  </div>
</template>
