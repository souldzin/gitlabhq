import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import SignInOauthButton from '~/jira_connect/subscriptions/components/sign_in_oauth_button.vue';
import {
  I18N_DEFAULT_SIGN_IN_BUTTON_TEXT,
  OAUTH_WINDOW_OPTIONS,
} from '~/jira_connect/subscriptions/constants';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';
import httpStatus from '~/lib/utils/http_status';
import AccessorUtilities from '~/lib/utils/accessor';
import { getCurrentUser } from '~/rest_api';
import createStore from '~/jira_connect/subscriptions/store';
import { SET_ACCESS_TOKEN } from '~/jira_connect/subscriptions/store/mutation_types';

jest.mock('~/lib/utils/accessor');
jest.mock('~/jira_connect/subscriptions/utils');
jest.mock('~/jira_connect/subscriptions/api');
jest.mock('~/rest_api');
jest.mock('~/jira_connect/subscriptions/pkce', () => ({
  createCodeVerifier: jest.fn().mockReturnValue('mock-verifier'),
  createCodeChallenge: jest.fn().mockResolvedValue('mock-challenge'),
}));

const mockOauthMetadata = {
  oauth_authorize_url: 'https://gitlab.com/mockOauth',
  oauth_token_url: 'https://gitlab.com/mockOauthToken',
  state: 'good-state',
};

describe('SignInOauthButton', () => {
  let wrapper;
  let mockAxios;
  let store;

  const createComponent = ({ slots } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
    jest.spyOn(store, 'commit').mockImplementation();

    wrapper = shallowMount(SignInOauthButton, {
      store,
      slots,
      provide: {
        oauthMetadata: mockOauthMetadata,
      },
    });
  };

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    mockAxios.restore();
  });

  const findButton = () => wrapper.findComponent(GlButton);

  it('displays a button', () => {
    createComponent();

    expect(findButton().exists()).toBe(true);
    expect(findButton().text()).toBe(I18N_DEFAULT_SIGN_IN_BUTTON_TEXT);
  });

  it.each`
    scenario                            | cryptoAvailable
    ${'when crypto API is available'}   | ${true}
    ${'when crypto API is unavailable'} | ${false}
  `('$scenario when canUseCrypto returns $cryptoAvailable', ({ cryptoAvailable }) => {
    AccessorUtilities.canUseCrypto = jest.fn().mockReturnValue(cryptoAvailable);
    createComponent();

    expect(findButton().props('disabled')).toBe(!cryptoAvailable);
  });

  describe('on click', () => {
    beforeEach(async () => {
      jest.spyOn(window, 'open').mockReturnValue();
      createComponent();

      findButton().vm.$emit('click');

      await nextTick();
    });

    it('sets `loading` prop of button to `true`', () => {
      expect(findButton().props('loading')).toBe(true);
    });

    it('calls `window.open` with correct arguments', () => {
      expect(window.open).toHaveBeenCalledWith(
        `${mockOauthMetadata.oauth_authorize_url}?code_challenge=mock-challenge&code_challenge_method=S256`,
        I18N_DEFAULT_SIGN_IN_BUTTON_TEXT,
        OAUTH_WINDOW_OPTIONS,
      );
    });

    it('sets the `codeVerifier` internal state', () => {
      expect(wrapper.vm.codeVerifier).toBe('mock-verifier');
    });

    describe('on window message event', () => {
      describe('when window message properties are corrupted', () => {
        describe.each`
          origin           | state                      | messageOrigin    | messageState
          ${window.origin} | ${mockOauthMetadata.state} | ${'bad-origin'}  | ${mockOauthMetadata.state}
          ${window.origin} | ${mockOauthMetadata.state} | ${window.origin} | ${'bad-state'}
        `(
          'when message is [state=$messageState, origin=$messageOrigin]',
          ({ messageOrigin, messageState }) => {
            beforeEach(async () => {
              const mockEvent = {
                origin: messageOrigin,
                data: {
                  state: messageState,
                  code: '1234',
                },
              };
              window.dispatchEvent(new MessageEvent('message', mockEvent));
              await waitForPromises();
            });

            it('does not emit `sign-in` event', () => {
              expect(wrapper.emitted('sign-in')).toBeFalsy();
            });

            it('sets `loading` prop of button to `false`', () => {
              expect(findButton().props('loading')).toBe(false);
            });
          },
        );
      });

      describe('when window message properties are valid', () => {
        const mockAccessToken = '5678';
        const mockUser = { name: 'test user' };
        const mockEvent = {
          origin: window.origin,
          data: {
            state: mockOauthMetadata.state,
            code: '1234',
          },
        };

        describe('when API requests succeed', () => {
          beforeEach(async () => {
            jest.spyOn(axios, 'post');
            jest.spyOn(axios, 'get');
            mockAxios
              .onPost(mockOauthMetadata.oauth_token_url)
              .replyOnce(httpStatus.OK, { access_token: mockAccessToken });
            getCurrentUser.mockResolvedValue({ data: mockUser });

            window.dispatchEvent(new MessageEvent('message', mockEvent));

            await waitForPromises();
          });

          it('executes POST request to Oauth token endpoint', () => {
            expect(axios.post).toHaveBeenCalledWith(mockOauthMetadata.oauth_token_url, {
              code: '1234',
              code_verifier: 'mock-verifier',
            });
          });

          it('dispatches loadCurrentUser action', () => {
            expect(store.dispatch).toHaveBeenCalledWith('loadCurrentUser', mockAccessToken);
          });

          it('commits SET_ACCESS_TOKEN mutation with correct access token', () => {
            expect(store.commit).toHaveBeenCalledWith(SET_ACCESS_TOKEN, mockAccessToken);
          });

          it('emits `sign-in` event with user data', () => {
            expect(wrapper.emitted('sign-in')[0]).toBeTruthy();
          });
        });

        describe('when API requests fail', () => {
          beforeEach(async () => {
            jest.spyOn(axios, 'post');
            mockAxios
              .onPost(mockOauthMetadata.oauth_token_url)
              .replyOnce(httpStatus.INTERNAL_SERVER_ERROR);

            window.dispatchEvent(new MessageEvent('message', mockEvent));

            await waitForPromises();
          });

          it('emits `error` event', () => {
            expect(wrapper.emitted('error')[0]).toEqual([]);
          });

          it('does not emit `sign-in` event', () => {
            expect(wrapper.emitted('sign-in')).toBeFalsy();
          });

          it('sets `loading` prop of button to `false`', () => {
            expect(findButton().props('loading')).toBe(false);
          });
        });
      });
    });
  });
});
