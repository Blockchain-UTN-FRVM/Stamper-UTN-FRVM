// SPDX-License-Identifier: MIT
pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/EnumerableSet.sol";

contract StamperUTNFRVMV5 is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Stamp {
        bytes32 hash;
        uint256 idUsuario;
        uint256 blockNo;
    }

    Stamp[] private stampList;
    mapping(bytes32 => mapping(uint256 => bool)) private stampedByUser;
    mapping(uint256 => uint256[]) private userStamps;

    EnumerableSet.AddressSet private authorizedAddresses;
    uint256 private hashListMaxLength = 100;

    event Stamped(bytes32 indexed hash, uint256 indexed idUsuario);
    event HashAlreadyStamped(bytes32 indexed hash, uint256 indexed idUsuario);
    event ListMaxLengthChanged(uint256 newMaxLength);
    event AddressAuthorized(address indexed authAddress);
    event AddressRevoked(address indexed addressRevoked);

    modifier onlyAuthorized() {
        require(msg.sender == owner() || authorizedAddresses.contains(msg.sender),
            "Address no autorizada"
        );
        _;
    }

    // Autorizar o revocar direcciones
    function authorizeAddress(address authAddress) external onlyOwner {
        require(authAddress != address(0), "Direccion invalida");
        authorizedAddresses.add(authAddress); // no se agregan duplicados gracias a EnumerableSet
        emit AddressAuthorized(authAddress);
    }

    function revokeAddress(address addressRevoked) external onlyOwner {
        require(addressRevoked != address(0), "Direccion invalida");
        authorizedAddresses.remove(addressRevoked);
        emit AddressRevoked(addressRevoked);
    }

    function getAuthorizedAddresses() external view returns (address[] memory) {
        uint256 authAddressesLength = authorizedAddresses.length();
        address[] memory list = new address[](authAddressesLength);
        for (uint256 i = 0; i < authAddressesLength; i++) {
            list[i] = authorizedAddresses.get(i);
        }
        return list;
    }

    // Validar longitud de lista de hashes
    function hashListLength(bytes32[] memory hashList) public view returns (bool) {
        return (hashList.length > 0 && hashList.length <= hashListMaxLength);
    }

    // Cambiar máximo permitido de hashes por llamada
    function setHashListMaxLength(uint256 newMax) external onlyOwner {
        require(newMax > 0, "El maximo debe ser mayor a cero");
        hashListMaxLength = newMax;
        emit ListMaxLengthChanged(newMax);
    }

    // Registrar lista de hashes
    function postHash(bytes32[] calldata hashList, uint256 idUsuario
    ) external onlyAuthorized returns (bytes32[] memory, bytes32[] memory) {
        require(hashListLength(hashList), "Tamanio de lista de hashes invalido");

        uint256 hashLength = hashList.length;
        bytes32[] memory tempStamped = new bytes32[](hashLength);
        bytes32[] memory tempAlready = new bytes32[](hashLength);
        uint256 stampedCount = 0;
        uint256 alreadyCount = 0;

        for (uint256 i = 0; i < hashLength; i++) {
            bytes32 hash = hashList[i];

            if (stampedByUser[hash][idUsuario]) {
                tempAlready[alreadyCount] = hash;
                alreadyCount++;
                emit HashAlreadyStamped(hash, idUsuario);
                continue;
            }

            // Registrar nuevo stamp
            stampedByUser[hash][idUsuario] = true;
            stampList.push(Stamp(hash, idUsuario, block.number));
            uint256 newIndex = stampList.length - 1;
            userStamps[idUsuario].push(newIndex);

            tempStamped[stampedCount] = hash;
            stampedCount++;
            emit Stamped(hash, idUsuario);
        }

        bytes32[] memory hashesStamped = new bytes32[](stampedCount);
        for (uint256 i = 0; i < stampedCount; i++) {
            hashesStamped[i] = tempStamped[i];
        }

        bytes32[] memory hashesAlreadyStamped = new bytes32[](alreadyCount);
        for (uint256 i = 0; i < alreadyCount; i++) {
            hashesAlreadyStamped[i] = tempAlready[i];
        }

        return (hashesStamped, hashesAlreadyStamped);
    }

    // Validar un hash específico y devolver si existe, lista de usuarios y block numbers
    function validateHash(bytes32 hash) public view returns (bool, bytes32, uint256[] memory, uint256[] memory, address) {
        uint256 totalUsers = 0;

        // Contar cuántos usuarios han registrado el hash
        for (uint256 i = 0; i < stampList.length; i++) {
            if (stampList[i].hash == hash) {
                totalUsers++;
            }
        }

        if (totalUsers == 0) {
            return (false, bytes32(0), new uint256[](0), new uint256[](0), address(this));
        }

        uint256[] memory idUsuarios = new uint256[](totalUsers);
        uint256[] memory blockNos = new uint256[](totalUsers);
        uint256 counter = 0;

        for (uint256 i = 0; i < stampList.length; i++) {
            if (stampList[i].hash == hash) {
                idUsuarios[counter] = stampList[i].idUsuario;
                blockNos[counter] = stampList[i].blockNo;
                counter++;
            }
        }

        return (true, hash, idUsuarios, blockNos, address(this));
    }

    // Obtener todos los hashes registrados por un usuario
    function getHashesByUser(uint256 idUsuario) public view returns (bytes32[] memory, uint256[] memory) {
        uint256[] storage users = userStamps[idUsuario];
        uint256 usersLength = users.length;

        bytes32[] memory hashes = new bytes32[](usersLength);
        uint256[] memory blockNos = new uint256[](usersLength);

        for (uint256 i = 0; i < usersLength; i++) {
            Stamp storage stamp = stampList[users[i]];
            hashes[i] = stamp.hash;
            blockNos[i] = stamp.blockNo;
        }

        return (hashes, blockNos);
    }
}
