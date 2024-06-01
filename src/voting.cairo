use Voting::Candidate;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVoting<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_current_president(self: @TContractState) -> Candidate;
    fn add_candidate(ref self: TContractState, candidate: ContractAddress, name: felt252);
    fn get_candidate(self: @TContractState, candidate_id: u32) -> Candidate;
    fn set_proposal(ref self: TContractState, proposal: ByteArray);
    fn get_proposal(self: @TContractState) -> ByteArray;
    fn register_voter(ref self: TContractState, voter: ContractAddress);
    fn get_winner(self: @TContractState) -> Candidate;
    fn get_candidates(self: @TContractState) -> Array<Candidate>;
    fn vote(ref self: TContractState, candidate_id: u32);
    fn end_voting(ref self: TContractState);
}

#[starknet::contract]
pub mod Voting {
    use core::starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address};
    use super::IVoting;

    #[storage]
    struct Storage {
        proposal: ByteArray,
        owner: ContractAddress,
        next_candidate_id: u32,
        total_voters: u32,
        candidates: LegacyMap::<u32, Candidate>,
        voters: LegacyMap::<ContractAddress, bool>,
        voted: LegacyMap::<ContractAddress, bool>,
        voting_ended: bool,
        winner: Candidate,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CandidateAdded: CandidateAdded,
        VoterRegistered: VoterRegistered,
        Voted: Voted,
        VotingEnded: VotingEnded,
    }

    #[derive(Drop, starknet::Event)]
    struct CandidateAdded {
        #[key]
        id: u32,
        address: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct VoterRegistered {
        address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Voted {
        #[key]
        candidate_id: u32,
        voter: ContractAddress,
    }

    #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
    pub struct Candidate {
        pub id: u32,
        pub name: felt252,
        pub address: ContractAddress,
        pub votes: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingEnded {
        #[key]
        winner_id: u32,
        winner_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl VotingImpl of IVoting<ContractState> {
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_current_president(self: @ContractState) -> Candidate {
            let mut index = 1;
            let mut winner = self.candidates.read(0);
            while index < self.next_candidate_id.read() {
                let candidate = self.candidates.read(index);
                if candidate.votes > winner.votes {
                    winner = candidate;
                }
                index += 1;
            };
            winner
        }

        fn register_voter(ref self: ContractState, voter: ContractAddress) {
            self._is_owner();
            self.total_voters.write(self.total_voters.read() + 1);
            self.voters.write(voter, true);
            self.emit(VoterRegistered { address: voter });
        }

        fn set_proposal(ref self: ContractState, proposal: ByteArray) {
            self._is_owner();
            self.proposal.write(proposal);
        }

        fn get_proposal(self: @ContractState) -> ByteArray {
            self.proposal.read()
        }

        fn add_candidate(ref self: ContractState, candidate: ContractAddress, name: felt252) {
            self._is_owner();
            let candidate_id = self.next_candidate_id.read();
            self.next_candidate_id.write(candidate_id + 1);
            self
                .candidates
                .write(
                    candidate_id,
                    Candidate { id: candidate_id, name, address: candidate, votes: 0, }
                );
            self.emit(CandidateAdded { id: candidate_id, address: candidate, name, });
        }

        fn vote(ref self: ContractState, candidate_id: u32) {
            self._is_registered_voter();
            self._is_voted();
            self._is_voting_ended();
            let candidate = self.candidates.read(candidate_id);
            self
                .candidates
                .write(candidate_id, Candidate { votes: candidate.votes + 1, ..candidate });

            self.emit(Voted { candidate_id, voter: get_caller_address() });
        }

        fn get_candidate(self: @ContractState, candidate_id: u32) -> Candidate {
            InternalImpl::_is_candidate(self, candidate_id);
            self.candidates.read(candidate_id)
        }

        fn get_candidates(self: @ContractState) -> Array<Candidate> {
            let mut index = 0;
            let mut candidates = ArrayTrait::new();
            while index < self.next_candidate_id.read() {
                candidates.append(self.candidates.read(index));
                index += 1;
            };
            candidates
        }

        fn get_winner(self: @ContractState) -> Candidate {
            assert(self.voting_ended.read(), 'VOTING NOT ENDED');
            self.winner.read()
        }

        fn end_voting(ref self: ContractState) {
            self._is_owner();
            let winner = self.get_current_president();
            self.voting_ended.write(true);
            self.winner.write(winner);

            self.emit(VotingEnded { winner_id: winner.id, winner_address: winner.address });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _is_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'NOT OWNER');
        }

        fn _is_registered_voter(self: @ContractState) {
            let caller = get_caller_address();
            assert(self.voters.read(caller), 'NOT VOTER');
        }

        fn _is_candidate(self: @ContractState, candidate_id: u32) {
            assert(candidate_id <= self.next_candidate_id.read(), 'NOT CANDIDATE');
        }

        fn _is_voted(self: @ContractState) {
            let caller = get_caller_address();
            assert(!self.voted.read(caller), 'ALREADY VOTED');
        }

        fn _is_voting_ended(self: @ContractState) {
            assert(!self.voting_ended.read(), 'VOTING ENDED');
        }
    }
}