// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWorldID} from "world-id-contracts/interfaces/IWorldID.sol";
import {ByteHasher} from "world-id-contracts/libraries/ByteHasher.sol";

contract WorldIDRaffle {
    using ByteHasher for bytes;

    error RaffleEnded();
    error RaffleRunning();
    error InvalidNullifier();

    event CreatedRaffle(uint256 raffleId, address indexed creator);
    event JoinedRaffle(uint256 indexed raffleId, address indexed participant);
    event EndedRaffle(uint256 indexed raffleId, address indexed winner);

    struct Raffle {
        uint256 seed;
        uint256 endsAt;
        address winner;
        uint256 participantCount;
    }

    string public actionId;
    IWorldID public immutable worldId;

    uint256 internal nextRaffleId = 1;
    mapping(uint256 => Raffle) public getRaffle;
    mapping(uint256 => mapping(uint256 => address)) public getParticipant;

    mapping(uint256 => bool) internal nullifierHashes;

    constructor(IWorldID _worldId, string memory _actionId) {
        worldId = _worldId;
        actionId = _actionId;
    }

    function create(uint256 endsAt) public {
        getRaffle[nextRaffleId].endsAt = endsAt;

        emit CreatedRaffle(nextRaffleId++, msg.sender);
    }

    function enter(
        address receiver,
        uint256 raffleId,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();
        if (getRaffle[raffleId].endsAt < block.timestamp) revert RaffleEnded();

        worldId.verifyProof(
            root,
            1,
            abi.encodePacked(receiver).hashToField(),
            nullifierHash,
            abi.encodePacked(actionId, raffleId).hashToField(),
            proof
        );

        getParticipant[raffleId][
            getRaffle[raffleId].participantCount++
        ] = receiver;

        getRaffle[raffleId].seed ^= nullifierHash;

        emit JoinedRaffle(raffleId, receiver);
    }

    function settle(uint256 raffleId) public {
        if (getRaffle[raffleId].endsAt > block.timestamp)
            revert RaffleRunning();

        getRaffle[raffleId].winner = getParticipant[raffleId][
            getRaffle[raffleId].seed % getRaffle[raffleId].participantCount
        ];

        emit EndedRaffle(raffleId, getRaffle[raffleId].winner);
    }
}
