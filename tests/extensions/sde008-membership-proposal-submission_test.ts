
import { 
  Clarinet, 
  Tx, 
  Chain, 
  Account, 
  types, 
} from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';
import { ExecutorDao } from '../models/executor-dao-model.ts';
import { SDE008MembershipProposalSubmission, MEMBERSHIP_PROPOSAL_SUBMISSION_CODES } from '../models/sde008-membership-proposal-submission-model.ts';
import { EXTENSIONS, PROPOSALS } from '../models/utils/contract-addresses.ts';

Clarinet.test({
  name: 'SDE008MembershipProposalSubmission',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get('deployer')!;
    let Dao = new ExecutorDao(chain);
    let ProposalSubmission = new SDE008MembershipProposalSubmission(chain);
    let result: any = null;
    
    // 1a. should return an error if caller is trying to set member contract from anything other than extension or DAO
    result = await ProposalSubmission.setMemberContract(deployer, types.principal(EXTENSIONS.sde006Membership));
    result.expectErr().expectUint(MEMBERSHIP_PROPOSAL_SUBMISSION_CODES.ERR_UNAUTHORIZED);

    // 2a. add proposal to change the membership contract address
    // 2b. verify new proposal is added to the proposal queue

    // 3a. simulate approval votes for proposal
    // 3b. conclude approval vote for the proposal
    
  },
});
