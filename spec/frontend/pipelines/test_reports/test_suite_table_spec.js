import { GlButton, GlFriendlyWrap, GlLink, GlPagination, GlEmptyState } from '@gitlab/ui';
import Vue from 'vue';
import Vuex from 'vuex';
import testReports from 'test_fixtures/pipelines/test_report.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SuiteTable, { i18n } from '~/pipelines/components/test_reports/test_suite_table.vue';
import { TestStatus } from '~/pipelines/constants';
import * as getters from '~/pipelines/stores/test_reports/getters';
import { formatFilePath } from '~/pipelines/stores/test_reports/utils';
import { ARTIFACTS_EXPIRED_ERROR_MESSAGE } from '~/pipelines/stores/test_reports/constants';
import skippedTestCases from './mock_data';

Vue.use(Vuex);

describe('Test reports suite table', () => {
  let wrapper;
  let store;

  const {
    test_suites: [testSuite],
  } = testReports;

  testSuite.test_cases = [...testSuite.test_cases, ...skippedTestCases];
  const testCases = testSuite.test_cases;
  const blobPath = '/test/blob/path';

  const noCasesMessage = () => wrapper.findByTestId('no-test-cases');
  const artifactsExpiredMessage = () => wrapper.findByTestId('artifacts-expired');
  const artifactsExpiredEmptyState = () => wrapper.find(GlEmptyState);
  const allCaseRows = () => wrapper.findAllByTestId('test-case-row');
  const findCaseRowAtIndex = (index) => wrapper.findAllByTestId('test-case-row').at(index);
  const findLinkForRow = (row) => row.find(GlLink);
  const findIconForRow = (row, status) => row.find(`.ci-status-icon-${status}`);

  const createComponent = ({ suite = testSuite, perPage = 20, errorMessage } = {}) => {
    store = new Vuex.Store({
      state: {
        blobPath,
        testReports: {
          test_suites: [suite],
        },
        selectedSuiteIndex: 0,
        pageInfo: {
          page: 1,
          perPage,
        },
        errorMessage,
      },
      getters,
    });

    wrapper = shallowMountExtended(SuiteTable, {
      store,
      stubs: { GlFriendlyWrap },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('should render a message when there are no test cases', () => {
    createComponent({ suite: [] });

    expect(noCasesMessage().exists()).toBe(true);
    expect(artifactsExpiredMessage().exists()).toBe(false);
  });

  it('should render an empty state when artifacts have expired', () => {
    createComponent({ suite: [], errorMessage: ARTIFACTS_EXPIRED_ERROR_MESSAGE });
    const emptyState = artifactsExpiredEmptyState();

    expect(noCasesMessage().exists()).toBe(false);
    expect(artifactsExpiredMessage().exists()).toBe(true);

    expect(emptyState.exists()).toBe(true);
    expect(emptyState.props('title')).toBe(i18n.expiredArtifactsTitle);
  });

  describe('when a test suite is supplied', () => {
    beforeEach(() => createComponent());

    it('renders the correct number of rows', () => {
      expect(allCaseRows()).toHaveLength(testCases.length);
    });

    it.each([
      TestStatus.ERROR,
      TestStatus.FAILED,
      TestStatus.SKIPPED,
      TestStatus.SUCCESS,
      'unknown',
    ])('renders the correct icon for test case with %s status', (status) => {
      const test = testCases.findIndex((x) => x.status === status);
      const row = findCaseRowAtIndex(test);

      expect(findIconForRow(row, status).exists()).toBe(true);
    });

    it('renders the file name for the test with a copy button', () => {
      const { file } = testCases[0];
      const relativeFile = formatFilePath(file);
      const filePath = `${blobPath}/${relativeFile}`;
      const row = findCaseRowAtIndex(0);
      const fileLink = findLinkForRow(row);
      const button = row.find(GlButton);

      expect(fileLink.attributes('href')).toBe(filePath);
      expect(row.text()).toContain(file);
      expect(button.exists()).toBe(true);
      expect(button.attributes('data-clipboard-text')).toBe(file);
    });
  });

  describe('when a test suite has more test cases than the pagination size', () => {
    const perPage = 2;

    beforeEach(() => {
      createComponent({ testSuite, perPage });
    });

    it('renders one page of test cases', () => {
      expect(allCaseRows().length).toBe(perPage);
    });

    it('renders a pagination component', () => {
      expect(wrapper.find(GlPagination).exists()).toBe(true);
    });
  });

  describe('when a test case classname property is null', () => {
    it('still renders all test cases', () => {
      createComponent({
        testSuite: {
          ...testSuite,
          test_cases: testSuite.test_cases.map((testCase) => ({
            ...testCase,
            classname: null,
          })),
        },
      });

      expect(allCaseRows()).toHaveLength(testCases.length);
    });
  });

  describe('when a test case name property is null', () => {
    it('still renders all test cases', () => {
      createComponent({
        testSuite: {
          ...testSuite,
          test_cases: testSuite.test_cases.map((testCase) => ({
            ...testCase,
            name: null,
          })),
        },
      });

      expect(allCaseRows()).toHaveLength(testCases.length);
    });
  });
});
