package tn.esprit.spring.dto;

public class UserDTO {

    private Long id;
    private String username;
    private String email;

    // Constructeur vide (utile pour JSON)
    public UserDTO() {
    }

    // Constructeur à partir de l'entité User
    public UserDTO(tn.esprit.spring.entities.User user) {
        this.id = user.getId();
        this.username = user.getLastName();   // ← corrige ici si le getter est différent
        this.email = null;         // ← corrige ici si le getter est différent
        // Ajoute d'autres champs si besoin, ex.:
        // this.firstName = user.getFirstName();
    }

    // Getters et setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
