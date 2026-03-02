package tn.esprit.spring.control;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import tn.esprit.spring.entities.User;
import tn.esprit.spring.services.IUserService;
import tn.esprit.spring.dto.UserDTO;
import tn.esprit.spring.dto.UserCreateDTO;

@RestController
@RequestMapping("/user")
public class UserRestControl {

    @Autowired
    private IUserService userService;

    // GET all users
    @GetMapping("/retrieve-all-users")
    public List<User> retrieveAllUsers() {
        return userService.retrieveAllUsers();
    }

    // GET one user - retour DTO
    @GetMapping("/retrieve-user/{user-id}")
    public UserDTO retrieveUser(@PathVariable("user-id") String userId) {
        User user = userService.retrieveUser(userId);
        return new UserDTO(user);
    }

    // POST add user - entrée DTO, retour DTO
    @PostMapping("/add-user")
    public UserDTO addUser(@RequestBody UserCreateDTO createDTO) {
        User userToSave = new User();
        userToSave.setLastName(createDTO.getLastName());

        User savedUser = userService.addUser(userToSave);
        return new UserDTO(savedUser);
    }

    // PUT update user - retour DTO
    
	@PutMapping("/modify-user")
public UserDTO updateUser(@RequestBody UserCreateDTO updateDTO) {
    User userToUpdate = new User();
    userToUpdate.setLastName(updateDTO.getLastName());
    // Ajoute d'autres champs si tu en as dans le DTO (ex. setEmail, setFirstName...)

    User updatedUser = userService.updateUser(userToUpdate);
    return new UserDTO(updatedUser);
}
    // DELETE user
    @DeleteMapping("/remove-user/{user-id}")
    public void removeUser(@PathVariable("user-id") String userId) {
        userService.deleteUser(userId);
    }
}
