use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, cheat_caller_address, CheatSpan};

use voting::voting::IVotingDispatcher;
use voting::voting::IVotingDispatcherTrait;

use voting::voting::Voting::Candidate;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let mut calldata = ArrayTrait::new();

    let owner = contract_address_const::<0xabc>();

    calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_contract_deployment() {
    let contract_address = deploy_contract("Voting");

    let dispatcher = IVotingDispatcher { contract_address };
    let owner = dispatcher.get_owner();

    assert(owner == contract_address_const::<0xabc>(), 'Not owner');
}

#[test]
fn test_set_proposal() {
    let contract_address = deploy_contract("Voting");

    let dispatcher = IVotingDispatcher { contract_address };

    cheat_caller_address(contract_address, 0xabc.try_into().unwrap(), CheatSpan::TargetCalls(1));

    dispatcher.set_proposal("Proposal 1");

    let proposal_from_contract = dispatcher.get_proposal();
    assert(proposal_from_contract == "Proposal 1", 'Proposal not set');
}

#[test]
fn test_add_candidate() {
    let contract_address = deploy_contract("Voting");

    let dispatcher = IVotingDispatcher { contract_address };

    cheat_caller_address(contract_address, 0xabc.try_into().unwrap(), CheatSpan::TargetCalls(3));

    dispatcher.add_candidate(contract_address_const::<0xc1>(), 'Candidate 1');

    let candidates = dispatcher.get_candidates();
    assert(candidates.len() == 1, 'Candidate not added');

    dispatcher.add_candidate(contract_address_const::<0xc2>(), 'Candidate 2');

    let candidates = dispatcher.get_candidates();
    assert(candidates.len() == 2, 'Candidate not added');
}

#[test]
fn test_voting() {
    let contract_address = deploy_contract("Voting");

    let dispatcher = IVotingDispatcher { contract_address };

    add_candidates(contract_address);
    add_voters(contract_address);

    cheat_caller_address(contract_address, 0xc1.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(1);

    cheat_caller_address(contract_address, 0xc2.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(1);

    cheat_caller_address(contract_address, 0xc3.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(0);

    let current_leader = dispatcher.get_current_president();

    assert(current_leader.id == 1, 'Wrong leader');
    assert(current_leader.name == 'Candidate 2', 'Wrong leader name');
}

#[test]
fn test_end_voting() {
    let contract_address = deploy_contract("Voting");

    let dispatcher = IVotingDispatcher { contract_address };

    add_voters_and_vote(contract_address);

    cheat_caller_address(contract_address, 0xabc.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.end_voting();

    let winner = dispatcher.get_winner();

    assert(winner.id == 1, 'Wrong winner');
    assert(winner.name == 'Candidate 2', 'Wrong winner name');
}

fn add_candidates(contract_address: ContractAddress) {
    let dispatcher = IVotingDispatcher { contract_address };

    cheat_caller_address(contract_address, 0xabc.try_into().unwrap(), CheatSpan::TargetCalls(3));

    dispatcher.add_candidate(contract_address_const::<0xc1>(), 'Candidate 1');
    dispatcher.add_candidate(contract_address_const::<0xc2>(), 'Candidate 2');
    dispatcher.add_candidate(contract_address_const::<0xc3>(), 'Candidate 3');
}

fn add_voters(contract_address: ContractAddress) {
    let dispatcher = IVotingDispatcher { contract_address };

    cheat_caller_address(contract_address, 0xabc.try_into().unwrap(), CheatSpan::TargetCalls(3));

    dispatcher.register_voter(contract_address_const::<0xc1>());
    dispatcher.register_voter(contract_address_const::<0xc2>());
    dispatcher.register_voter(contract_address_const::<0xc3>());
}

fn add_voters_and_vote(contract_address: ContractAddress) {
    let dispatcher = IVotingDispatcher { contract_address };

    add_candidates(contract_address);
    add_voters(contract_address);

    cheat_caller_address(contract_address, 0xc1.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(1);

    cheat_caller_address(contract_address, 0xc2.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(1);

    cheat_caller_address(contract_address, 0xc3.try_into().unwrap(), CheatSpan::TargetCalls(1));
    dispatcher.vote(0);
}