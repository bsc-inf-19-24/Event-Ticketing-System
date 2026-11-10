
package com.ticketmaster.ticketmaster.events.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "events")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Event {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Foreign key referencing users.id

    @Column(name = "organizer_id")
    private Long organizerId;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 100)
    private String category = "Other";

    @Column(length = 80)
    private String genre;

    @Column(nullable = false, length = 200)
    private String venue;

    @Column(nullable = false, length = 300)
    private String location;

    // Existing database column
    @Column(name = "date_time", nullable = false)
    private LocalDateTime dateTime;

    @Column(name = "start_time", nullable = false)
    private LocalDateTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalDateTime endTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EventStatus status = EventStatus.DRAFT;

    // Used by the existing event ownership checks
    @Column(name = "organizer_username", nullable = false, length = 100)
    private String organizerUsername;

    @Column(name = "cover_image_path", length = 500)
    private String coverImagePath;

    public Event() {
    }

    // Validate and synchronize required date/time fields before saving
    @PrePersist
    @PreUpdate
    public void validateAndSynchronizeTimes() {
        if (startTime == null) {
            startTime = dateTime;
        }
        if (dateTime == null) {
            dateTime = startTime;
        }
        if (startTime != null) {
            startTime = startTime.withNano(0);
            dateTime = startTime;
        }
        if (endTime != null) {
            endTime = endTime.withNano(0);
        }

        if (startTime == null || endTime == null) {
            throw new IllegalStateException(
                    "Event start time and end time are required");
        }

        if (!endTime.isAfter(startTime)) {
            throw new IllegalStateException(
                    "Event end time must be after start time");
        }
    }

    public Long getId() {
        return id;
    }

    public Long getOrganizerId() {
        return organizerId;
    }

    public void setOrganizerId(Long organizerId) {
        this.organizerId = organizerId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category == null || category.isBlank() ? "Other" : category;
    }

    public String getGenre() {
        return genre;
    }

    public void setGenre(String genre) {
        this.genre = genre;
    }

    public String getVenue() {
        return venue;
    }

    public void setVenue(String venue) {
        this.venue = venue;
    }

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    public LocalDateTime getDateTime() {
        return dateTime;
    }

    public void setDateTime(LocalDateTime dateTime) {
        this.dateTime = dateTime;
    }

    public LocalDateTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalDateTime startTime) {
        this.startTime = startTime;
        this.dateTime = startTime;
    }

    public LocalDateTime getEndTime() {
        return endTime;
    }

    public void setEndTime(LocalDateTime endTime) {
        this.endTime = endTime;
    }

    public EventStatus getStatus() {
        return status;
    }

    public void setStatus(EventStatus status) {
        this.status = status;
    }

    public String getOrganizerUsername() {
        return organizerUsername;
    }

    public void setOrganizerUsername(String organizerUsername) {
        this.organizerUsername = organizerUsername;
    }

    public String getCoverImagePath() {
        return coverImagePath;
    }

    public void setCoverImagePath(String coverImagePath) {
        this.coverImagePath = coverImagePath;
    }
}
